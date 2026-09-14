# Terraform Azure Githup Template

## Description

An opinionated terraform structure for running multi env infra in Azure

this follows structures from

https://www.terraform-best-practices.com/

main.tf - Setup for australia east webapp and Linux ubuntu VM with output of public IP address

## Key components

- Isolated 'environments' root terraform modules to reduce blast radius
- Isolated terraform remote state storage by environment to reduce blast radius
- Role Based Access Control for state storage blob access
- Named `/modules` files for easy location in VSCode (instead of lots of main.tf files)
- Github Actions with: Linting, Sec check, Environment controls for workflow approval

## Folder structure

│
├── compositions/ - any complex compositions of modules to be used by the root terraform can go here, such as project components eg: function app + storage + vnet
├── environments/ - each target environment has its own subfolder, under that root terraform. This is to reduce blast radius
├── modules/ - Terraform modules
└── scripts/ - Az CLI scripts to setup terraform remote state store and github actions access to azure

## Requriements

- Role 'Storage Blob Data Contributor' for any developers and CICD (this is set if using ./scripts files)

## Developer Setup

After cloning a repo:

```
terraform init -backend-config=<fullpathtobackend.hcl>
terraform workspace create dev

...
before commiting changes
terraform fmt -recursive
...

```

Only used when doing localdev work to keep CI dev state left alone

## Admin Setup

### Github Setup

Setup Github secrets: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID
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
