#!/usr/bin/env bash
set -euo pipefail

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
read -ra repos <<< "$GITHUB_REPOS"

# Safeguard against line breaks returned in az cli tsv query assignment
# to variables
az_tsv() {
  az "$@" -o tsv | tr -d '\r'
}

# get the az cli account subscriptionid
subscription_id=$(az_tsv account show --query id -o tsv)
tenant_id=$(az_tsv account show --query tenantId -o tsv)

echo "=== Using Subscription: ${subscription_id} - Tenant: ${tenant_id} ==="

random_suffix() {
  openssl rand -hex 4 | tr -dc 'a-z0-9' | head -c 6
}

for env in "${envs[@]}"; do
  echo "=== Setting up environment: ${env} ==="

  suffix=$(random_suffix)
  storage_name="sttfstate${env}${suffix}"
  resource_group="$RGPREFIX-$env"
  identity_name="id-terraform-cicd-$env"

  echo "Creating RG: $resource_group =="
  az group create -o none -n "$resource_group" -l "$LOCATION"

  echo "Creating StorageAccount: $storage_name"
  az storage account create -o none \
    -n "$storage_name" \
    -g "$resource_group" \
    -l "$LOCATION" \
    --sku "$STORAGE_SKU" \
    --allow-blob-public-access false \
    --min-tls-version "TLS1_2" \
    --allow-shared-key-access false \
    --default-action Allow \
    --require-infrastructure-encryption true \
    --tags environment="$env"

  echo "Creating Blob container: tfstate"
  az storage container create -o none \
    --account-name "$storage_name" \
    --name tfstate \
    --auth-mode login

  echo "Creating Blob container: tfplans"
  az storage container create -o none \
    --account-name "$storage_name" \
    --name tfplans \
    --auth-mode login

  echo "Creating Identity: $identity_name"
  az identity create -o none \
    --name "$identity_name" \
    --resource-group "$resource_group"

  # alternative older Service Principal / App registration if prefered
  # az ad app create --display-name "app-terraform"
  # # note the appId (client ID) and the app object id
  # $assignee = "" # the appid
  # $appObjectId = ""
  # az ad sp create --id $assignee

  identity_principal_id=$(az_tsv identity show -n "$identity_name" -g "$resource_group" --query principalId -o tsv)
  identity_client_id=$(az_tsv identity show -n "$identity_name" -g "$resource_group" --query clientId -o tsv)
  echo "Identity principalId: ${identity_principal_id} clientId: ${identity_client_id}"

  echo "Assigning Role Contributor on /subscriptions/${subscription_id}/resourceGroups/${resource_group} for ${identity_name}"
  az role assignment create -o none \
    --assignee-object-id $identity_principal_id \
    --assignee-principal-type ServicePrincipal \
    --role "Contributor" \
    --scope "/subscriptions/${subscription_id}/resourceGroups/${resource_group}"

  echo "Assigning Role 'Storage Blob Data Contributor' on StorageAccount ${storage_name} for ${identity_name}"
  az role assignment create -o none \
    --assignee-object-id $identity_principal_id \
    --assignee-principal-type ServicePrincipal \
    --role "Storage Blob Data Contributor" \
    --scope "/subscriptions/${subscription_id}/resourceGroups/${resource_group}/providers/Microsoft.Storage/storageAccounts/${storage_name}"


  echo "=== Github Env secrets to add for Environment: $env ==="
  echo "AZURE_CLIENT_ID: $identity_client_id"
  echo "AZURE_TENANT_ID: $tenant_id"
  echo "AZURE_SUBSCRIPTION_ID: $subscription_id"
  echo "Run 'setup-cicd-credentials.sh' to assign these in your github account and setup deployment environments"
  echo ""W
  echo "=== Settings for your /environments/$env/backend.hcl file =="
  echo "resource_group_name = "$resource_group""
  echo "storage_account_name = "$storage_name""
  echo ""
  echo "=== Done with environment: $env creation ==="
  echo
done
