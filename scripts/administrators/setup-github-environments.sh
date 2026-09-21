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
: "${AZURE_TENANT_ID:?AZURE_TENANT_ID is not set in .env}"
: "${AZURE_SUBSCRIPTION_ID:?AZURE_SUBSCRIPTION_ID is not set in .env}"
: "${TFPLAN_STORAGE_ACCOUNTS:?TFPLAN_STORAGE_ACCOUNTS is not set in .env}"


read -ra all_envs <<< "$ENVS"
read -ra repos <<< "$GITHUB_REPOS"
read -ra tfplan_accounts <<< "$TFPLAN_STORAGE_ACCOUNTS"

new_envs=("$@")

if [[ ${#new_envs[@]} -gt 0 ]]; then
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

# TF_ENVIRONMENTS always reflects the full (post-append) .env list
all_envs_json=$(build_json_array "${all_envs[@]}")

for repo in "${repos[@]}"; do
  echo "=== Setting variable TF_ENVIRONMENTS='$all_envs_json' on $repo ==="
  gh variable set TF_ENVIRONMENTS --repo "$repo" --body "$all_envs_json"
done

for i in "${!target_envs[@]}"; do
  env=${target_envs[$i]}
  resource_group="$RGPREFIX-$env"
  storage_account=${tfplan_accounts[$i]}

  apply_identity_name="id-terraform-cicd-apply-$env"
  plan_identity_name="id-terraform-cicd-plan-$env"

  if ! az identity show -n "$apply_identity_name" -g "$resource_group" &>/dev/null; then
    echo "Skipping $env: identity $apply_identity_name not found in $resource_group (has this env been set up yet?)" >&2
    continue
  fi
  if ! az identity show -n "$plan_identity_name" -g "$resource_group" &>/dev/null; then
    echo "Skipping $env: identity $plan_identity_name not found in $resource_group (has this env been set up yet?)" >&2
    continue
  fi

  apply_client_id=$(az identity show -n "$apply_identity_name" -g "$resource_group" --query clientId -o tsv)
  plan_client_id=$(az identity show -n "$plan_identity_name" -g "$resource_group" --query clientId -o tsv)

  for repo in "${repos[@]}"; do
    repo_slug=$(slugify_repo "$repo")
    repo_id=$(gh api "repos/$repo" --jq '.id')

    owner="${repo%%/*}"
    owner_id=$(gh api "users/$owner" --jq '.id' 2>/dev/null || gh api "orgs/$owner" --jq '.id')

    echo "=== Provisioning GitHub Environments: $env / ${env}-plan for $repo ==="

    # name:GH-environment  identity_name  client_id  workflow-file
    for stage in "apply" "plan"; do
      if [[ "$stage" == "apply" ]]; then
        name="$env"
        identity_name="$apply_identity_name"
        client_id="$apply_client_id"
        workflow_file="tf-apply.yml"
      else
        name="${env}-plan"
        identity_name="$plan_identity_name"
        client_id="$plan_client_id"
        workflow_file="tf-plan.yml"
      fi

      job_workflow_ref="${repo}/.github/workflows/${workflow_file}@refs/heads/main"
      subject="repository_owner_id:${owner_id}:repository_id:${repo_id}:environment:${name}:job_workflow_ref:${job_workflow_ref}"

      echo "  -> federated credential for '$name' (identity: $identity_name, workflow: $workflow_file)"
      az identity federated-credential create \
        --name "fic-github-$repo_slug-$name" \
        --identity-name "$identity_name" \
        --resource-group "$resource_group" \
        --issuer "https://token.actions.githubusercontent.com" \
        --subject "$subject" \
        --audiences "api://AzureADTokenExchange" \
        &>/dev/null

      echo "  -> ensuring GitHub Environment '$name' exists on $repo"
      gh api --method PUT "repos/$repo/environments/$name" >/dev/null

      echo "  -> setting variables for GitHub Environment '$name' on $repo"
      gh variable set AZURE_CLIENT_ID --repo "$repo" --env "$name" --body "$client_id"
      gh variable set AZURE_TENANT_ID --repo "$repo" --env "$name" --body "$AZURE_TENANT_ID"
      gh variable set AZURE_SUBSCRIPTION_ID --repo "$repo" --env "$name" --body "$AZURE_SUBSCRIPTION_ID"
      gh variable set TF_PLAN_STORAGE_ACCOUNT --repo "$repo" --env "$name" --body "$storage_account"
    done
  done
done

echo "Done."
