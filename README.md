# Terraform Azure Githup Template

## Description

An opinionated terraform structure for running multi env infra in Azure

this follows some structures from the Medium size infrastructure code structure:
https://www.terraform-best-practices.com/examples/terraform/medium-size-infrastructure

## Key components

- Isolated 'environments' root terraform modules to reduce blast radius
- Isolated terraform remote state blob storage by environment to reduce blast radius
- TFPlan artifacts uploaded to blob storage (retention 7 days)
- Role Based Access Control for state storage blob access
- Named `/modules` files for easy location in VSCode (instead of lots of main.tf files)
- Github Actions with: Linting, Formatting, Sec check (checkov), Environment controls for workflow approval
- Pre-push hook to lint and (optionally) run checkov locally
- Prettier config for markdown / yaml / json

## Folder structure

azure-terraform-template
│
├── environments/ - each target azure environment has its own subfolder to reduce blast radius
├── modules/ - Terraform modules used by environments
└── scripts/ - Az CLI scripts to setup terraform remote state store and github actions access to azure

## Requriements

- Role 'Storage Blob Data Contributor' for any developers and CICD (this is set if using ./scripts files)

TerraformLinters.tflint

make

checkov

## Developer Setup

After cloning a repo:

```
git config core.hooksPath .githooks


cd environments/dev
./scripts/tf-init.sh/ps1

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

Create github envionrments with the same name used in scripts/administrators/.env by the script: setup-cicd-credentials.sh
Setup Github 6 secrets for each github environment: AZURE_CLIENT_ID_ENVNAME, AZURE_TENANT_ID_ENVNAME, AZURE_SUBSCRIPTION_ID_ENVNAME and the same with \_PLAN suffix

### Azure setup

If using Azure for remote store:

Ensure for at least prod environment to follow guidance on locking down the state storage
https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage

The setup scripts create storage and a user-assigned identity for github access to azure

Recommended for higher environments:

- Set storage from public to private vnet

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
└── function-app/
├── function-app.tf # calls modules/compute/functionapp + modules/storage/account
├── variables.tf
└── outputs.tf

environments/
└── dev/
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
