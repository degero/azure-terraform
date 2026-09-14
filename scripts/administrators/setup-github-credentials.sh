#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <org/repo> [-e env] [-r ref] [--no-gh]"
  echo
  echo "  <org/repo>   Required. e.g. octo-org/octo-template"
  echo "  -e env       Optional. Restrict to one environment (default: all envs in .env)"
  echo "  -r ref       Optional. Git ref to trust (default: refs/heads/main)"
  echo "  --no-gh      Optional. Skip GitHub Environment/secret setup (Azure only)"
  echo
  echo "Example: $0 octo-org/octo-template"
  echo "Example: $0 octo-org/octo-template -e prod -r refs/heads/release"
  exit 1
}

[[ $# -lt 1 ]] && usage

repo="$1"
shift

ref="refs/heads/main"
only_env=""
setup_gh=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    -e) only_env="$2"; shift 2 ;;
    -r) ref="$2"; shift 2 ;;
    --no-gh) setup_gh=false; shift ;;
    *) usage ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
env_file="$script_dir/.env"

if [[ ! -f "$env_file" ]]; then
  echo "Missing .env file at $env_file" >&2
  exit 1
fi

set -a
# shellcheck source=.env
source "$env_file"
set +a

read -ra envs <<< "$ENVS"

if [[ -n "$only_env" ]]; then
  envs=("$only_env")
fi

if [[ "$setup_gh" == true ]] && ! command -v gh &>/dev/null; then
  echo "Warning: gh CLI not found. Skipping GitHub Environment/secret setup." >&2
  echo "Install from https://cli.github.com/ or re-run with --no-gh to silence this." >&2
  setup_gh=false
fi

if [[ "$setup_gh" == true ]] && ! gh auth status &>/dev/null; then
  echo "Warning: gh CLI is not authenticated (run 'gh auth login'). Skipping GitHub setup." >&2
  setup_gh=false
fi

slugify_repo() {
  echo "$1" | tr '/' '-' | tr -cd 'a-zA-Z0-9-'
}

repo_slug=$(slugify_repo "$repo")
tenant_id=$(az account show --query tenantId -o tsv)
subscription_id="${SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"

for env in "${envs[@]}"; do
  resource_group="administration-tfstate-$env"
  identity_name="id-tf-cicd-$env"

  if ! az identity show -n "$identity_name" -g "$resource_group" &>/dev/null; then
    echo "Skipping $env: identity $identity_name not found in $resource_group (has this env been set up yet?)" >&2
    continue
  fi

  echo "=== Adding $repo ($ref) to environment: $env ==="

  az identity federated-credential create \
    --name "github-$env-$repo_slug" \
    --identity-name "$identity_name" \
    --resource-group "$resource_group" \
    --issuer "https://token.actions.githubusercontent.com" \
    --subject "repo:$repo:ref:$ref" \
    --audiences "api://AzureADTokenExchange"

  if [[ "$setup_gh" == false ]]; then
    continue
  fi

  identity_client_id=$(az identity show -n "$identity_name" -g "$resource_group" --query clientId -o tsv)

  echo "  -> ensuring GitHub Environment '$env' exists on $repo"
  # PUT is idempotent: creates the environment if missing, no-ops if it exists
  gh api --method PUT "repos/$repo/environments/$env" >/dev/null

  echo "  -> setting secrets for GitHub Environment '$env' on $repo"
  gh secret set AZURE_CLIENT_ID --repo "$repo" --env "$env" --body "$identity_client_id"
  gh secret set AZURE_TENANT_ID --repo "$repo" --env "$env" --body "$tenant_id"
  gh secret set AZURE_SUBSCRIPTION_ID --repo "$repo" --env "$env" --body "$subscription_id"
done

echo "Done."
