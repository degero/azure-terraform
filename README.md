# Terraform Azure Github Template

## Description

An opinionated template for developing Terraform with Github running multi env infra deployments in Azure.

This template is focused on the terraform and github cicd it is not opinionated on the Azure hosted terraform management infrastructure as this can vary greatly by organisation. Scripts are included to get a baseline running with blast radius by "Resource group per environment".

## Key components

- Isolated /environments/env-name root terraform modules to reduce blast radius / increased flexibility
- Isolated terraform federated credentials + 2 UMAI per env (plan,apply) + RBAC to blob storage by environment (tfstate, tfplans containers)
- TFPlan artifacts uploaded to blob storage (retention 7 days)
- Named `/modules` files for easy location in VSCode (instead of lots of main.tf files)
- Github Workflows with: Linting (tflint), Formatting (terraform fmt), Sec check (checkov), Github Environments for workflow approval, Dependabot (terraform, github actions), Doco generation (terraform-docs), Terraform Validate
- Pre-push hook to lint and (optionally) run checkov locally
- Prettier config for markdown / yaml / json

## Folder structure

azure-terraform-template
│
├── environments/ - each target azure environment has its own subfolder to reduce blast radius
├── modules/ - Terraform modules used by environments
└── scripts/ - Az CLI scripts to setup terraform remote state store and github actions access to azure

## Terraform AzureRM authentication

use_azuread_auth = true
use_oidc = true

- OpenID Connect / Workload identity federation (Recommended by Hashicorp)
- User Assigned Managed Identity with Federated Credentials (Recommended by Hashicorp)

## Requirements

## Administrators

- Subscription level contributor access
- AZ CLI logged in with target subscription set

### Developers

- Role 'Storage Blob Data Contributor' on the DEV tfstate blob storage
- TerraformLinters.tflint
- checkov

## Environment setup

### Administrators

1. Copy [](scripts/.env.example) to scripts/.env and update with your Azure environment
1. Setup TF state stores with [scripts/administrators/setup-azure-tfstate-store.sh](scripts/administrators/setup-azure-tfstate-store.sh)
1. Setup Github: CICD federated credentials, Environments, Environment vars [](/scripts/administrators/setup-cicd-credentials.sh)
1. Update Github Environments variable TF_PLAN_STORAGE_ACCOUNT with the appropriate storage account name

### Developers

If you have appropriate access, assign yourself access to the dev tfstate storage:

```
az role assignment create \
  --assignee "$(az ad signed-in-user show --query id -o tsv)" \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Storage/storageAccounts/<storage-account-name>/blobServices/default/containers/tfstate"
```

NOTE: If state storage is in a different subscription or tenant you will need access to these.

After cloning a repo:

```
git config core.hooksPath .githooks


cd environments/dev
../../scripts/tf-init.sh/ps1

terraform workspace new <issuenumber> (so workspace is unique)

# Make changes

terraform plan -out="tfplan"
terraform apply tfplan


# before committing changes run in repo root:




# after PR complete
terraform workspace select default
terraform workspace delete <issuenumber>


```

It is recommended to use a workspace for local dev to not interfere with the tfstate used by CI or other devs.

## Admin Setup

### Github Setup

IMPORTANT: ensure all naming is the same / same case. safest to keep all as lowercase one word

These are automated by scripts/setup-gh-environments.sh

Setup github environments with names in TF_ENVIRONMENTS. You can start with just ["dev"] to get started
Create github envionrments with the same name used in scripts/administrators/.env by the script: setup-cicd-credentials.sh

Setup Github 6 secrets for each github environment: AZURE_CLIENT_ID_ENVNAME, AZURE_TENANT_ID_ENVNAME,
AZURE_SUBSCRIPTION_ID_ENVNAME and the same with \_PLAN suffix

IMPORTANT: You will need to manually add the secret TFPLAN_STORAGE_ACCOUNT to each envs secrets (based on the state storage for that env)

### Azure setup

While the [bootstrapping admin scripts](./scripts/administrtion) ar based on the Terraform state / plan storage and deployed envs in the same subscription for simplicity. It is recommended to use [Subscription Democratisation](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-principles#subscription-democratization)

If using Azure for remote store:

Ensure for at least prod environment to follow guidance on locking down the state storage
https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage

The setup scripts create storage and a user-assigned identity for github access to azure

Recommended for higher environments:

- Set storage from public to private vnet
- Separate storage accounts for tfstate / tfplans
- Place terraform UAMI, federated credentials, storage etc in a separate subscription to deployment environments
- Isolate deployment envs to separate subscriptions

You could adopt components of the /bootstrap of [azure-samples/github-terraform-oidc-ci-cd](https://github.com/azure-samples/github-terraform-oidc-ci-cd) to implement these note however tfstate is only seperated by container.

modules/ ← atomic modules only (one resource type each)
├── compute/
│ ├── functionapp/
│ └── vm/
├── storage/
│ └── account/
├── networking/
│ ├── vnet/
│ └── subnet/
└── security/
└── keyvault/

compositions/ ← composite modules (patterns of primitives)
├── function-app/
├── function-app.tf # calls modules/compute/functionapp + modules/storage/account
├── variables.tf
└── outputs.tf

environments/
├── dev/
├── terraform.tfvars
├── backend.hcl
└── main.tf # calls compositions/function-app, modules/networking, etc.

### Azure tooling

aztfexport
https://learn.microsoft.com/en-us/azure/developer/terraform/azure-export-for-terraform/export-terraform-overview

## Troubleshooting

### Local dev

If there are any issues with githooks, set the permissions:

```bash
chmod +x .githooks/pre-push
chmod +x ./scripts/prepush.sh
```

### Github

#### Environments

For each target environment workflows expect two Github Environments: env and env-plan. This is done to allow env based var/secret acesss and independent approval gating.

#### Release please

Change in github: Settings->General->Pull Requests->Default Commit Message as PR title. This allow release please to correctly pick up and compose release notes on release.

### Azure

### Overview of env

$env-plan   — no protection rules, deployment branches: "No restriction"
$env — protection rules as appropriate (none for dev/test, required reviewers for staging/preprod)

$env-plan SP  →  subject: repo:$repo:environment:$env-plan
$env SP → subject: repo:$repo:environment:$env

## Links

https://github.com/terraform-linters/tflint

https://github.com/bridgecrewio/checkov

https://github.com/terraform-docs/gh-actions

https://github.com/Azure-Samples/terraform-github-actions

https://github.com/azure-samples/github-terraform-oidc-ci-cd

https://www.terraform-best-practices.com/examples/terraform/medium-size-infrastructure

https://developer.hashicorp.com/terraform/language/backend/azurerm
