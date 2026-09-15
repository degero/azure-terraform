# Terraform Azure Githup Template

## Description

An opinionated terraform structure for running multi env infra in Azure

this follows some structures from the Medium size infrastructure code structure:
https://www.terraform-best-practices.com/examples/terraform/medium-size-infrastructure

## Key components

- Isolated 'environments' root terraform modules to reduce blast radius
- Isolated terraform remote state storage by environment to reduce blast radius
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

winget install TerraformLinters.tflint

checkov

## Developer Setup

After cloning a repo:

```
git config core.hooksPath .githooks


cd environments/dev
./scripts/tf-init.sh/ps1

terraform workspace new <username or issuenumber>

# Make changes

terraform plan -out="tfplan"
terraform apply tfplan


# before committing changes run:

terraform fmt -recursive
./scripts/tf-lint.sh/ps1
checkov -d . --config-file .checkov.yaml


```

It is recommended to use a workspace for local dev to not interfere with the tfstate used by CI or other devs.

## Admin Setup

### Github Setup

Setup Github Environment secrets for the Environments: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID
Setup protection rules and approvers for higher environments

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

### Azure



## Links

https://github.com/terraform-linters/tflint

https://github.com/bridgecrewio/checkov

https://github.com/terraform-docs/gh-actions