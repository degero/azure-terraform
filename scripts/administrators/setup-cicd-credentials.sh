#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 [new-env ...]"
  echo
  echo "  [new-env ...]  Optional. New environment name(s) to append to .env"
  echo "                 and provision. Must NOT already exist in ENVS."
  echo "                 Default (no args): provision everything currently"
  echo "                 listed in .env's ENVS (initial setup)."
  echo
  echo "Repos are read from GITHUB_REPOS in .env — every listed repo gets"
  echo "credentials, GH Environments, secrets, and TF_ENVIRONMENTS set."
  echo
  echo "Scenarios:"
  echo "  Initial setup:      $0"
  echo "  Add new env(s):     $0 staging prod"
  exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

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

: "${ENVS:?ENVS is not set in .env}"
: "${GITHUB_REPOS:?GITHUB_REPOS is not set in .env}"
: "${RGPREFIX:?RGPREFIX is not set in .env}"

read -ra all_envs <<< "$ENVS"
read -ra repos <<< "$GITHUB_REPOS"

new_envs=("$@")

if [[ ${#new_envs[@]} -gt 0 ]]; then
  # Appending: reject anything that already exists, then update .env in place
  for env in "${new_envs[@]}"; do
    if [[ " ${all_envs[*]} " =~ " ${env} " ]]; then
      echo "Error: '$env' already exists in .env's ENVS. Nothing to append." >&2
      exit 1
    fi
  done

  if [[ $(( ${#all_envs[@]} + ${#new_envs[@]} )) -gt 8 ]]; then
    echo "Error: ENVS max length is 8 (.env comment) — refusing to append." >&2
    exit 1
  fi

  all_envs+=("${new_envs[@]}")
  all_envs_csv_space="${all_envs[*]}"

  sed -i.bak "s/^ENVS=.*/ENVS=\"${all_envs_csv_space}\"/" "$env_file"
  rm -f "${env_file}.bak"
  echo "=== Appended to .env: ENVS=\"${all_envs_csv_space}\" ==="

  target_envs=("${new_envs[@]}")
else
  # No args: initial setup, provision everything currently in .env
  target_envs=("${all_envs[@]}")
fi

if ! command -v gh &>/dev/null; then
  echo "gh CLI not found. Install from https://cli.github.com/" >&2
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo "gh CLI is not authenticated (run 'gh auth login')." >&2
  exit 1
fi

slugify_repo() {
  echo "$1" | tr '/' '-' | tr -cd 'a-zA-Z0-9-'
}

build_json_array() {
  local json="[" first=true
  for item in "$@"; do
    $first && first=false || json+=","
    json+="\"$item\""
  done
  json+="]"
  echo "$json"
}

all_envs_json=$(build_json_array "${all_envs[@]}")

tenant_id=$(az account show --query tenantId -o tsv)
subscription_id="${SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"

# TF_ENVIRONMENTS always reflects the full (post-append) .env list
all_envs_json=$(build_json_array "${all_envs[@]}")

for repo in "${repos[@]}"; do
  echo "=== Setting variable TF_ENVIRONMENTS='$all_envs_json' on $repo ==="
  gh variable set TF_ENVIRONMENTS --repo "$repo" --body "$all_envs_json"
done

for env in "${target_envs[@]}"; do
  resource_group="$RGPREFIX-$env"
  identity_name="id-terraform-cicd-$env"

  if ! az identity show -n "$identity_name" -g "$resource_group" &>/dev/null; then
    echo "Skipping $env: identity $identity_name not found in $resource_group (has this env been set up yet?)" >&2
    continue
  fi

  identity_client_id=$(az identity show -n "$identity_name" -g "$resource_group" --query clientId -o tsv)

  for repo in "${repos[@]}"; do
    repo_slug=$(slugify_repo "$repo")

    echo "=== Provisioning GitHub Envionrments: $env / ${env}-plan for $repo ==="

    for name in "$env" "${env}-plan"; do
      echo "  -> federated credential for '$name'"
      az identity federated-credential create \
        --name "fic-github-$repo_slug-$name" \
        --identity-name "$identity_name" \
        --resource-group "$resource_group" \
        --issuer "https://token.actions.githubusercontent.com" \
        --subject "repo:$repo:environment:$name" \
        --audiences "api://AzureADTokenExchange" \
        &>/dev/null

      echo "  -> ensuring GitHub Environment '$name' exists on $repo"
      # PUT is idempotent: creates the environment if missing, no-ops if it exists
      gh api --method PUT "repos/$repo/environments/$name" >/dev/null

      echo "  -> setting secrets for GitHub Environment '$name' on $repo"
      gh secret set AZURE_CLIENT_ID --repo "$repo" --env "$name" --body "$identity_client_id"
      gh secret set AZURE_TENANT_ID --repo "$repo" --env "$name" --body "$tenant_id"
      gh secret set AZURE_SUBSCRIPTION_ID --repo "$repo" --env "$name" --body "$subscription_id"
    done
  done
done

echo "Done."
