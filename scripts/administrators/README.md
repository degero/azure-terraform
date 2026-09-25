# Administrator setup

These script allow setup in Azure / Github for multiple environment terraform state and plan storage as well as user managed identities that GitHub can use to access storage and deploy terraform. There are 2 github environments per target environment allowing separate control over terraform plan and apply. It is designed for simplicity/ease of use and requires sec hardening as a prod implementation.

See the notes on the [setup-github-environments.sh](#setup-github-environmentssh) before running the next steps.

## Setup steps

To setup, copy `.env.example` to `.env`, fill in the values then run:

1. setup-azure-tfstate-store.sh
1. setup-github-environments.sh
1. setup-github-oidc-subject.sh

### Configure terraform and Github

1. With the output from setup-azure-tfstate-store.sh, copy `backend.hcl.example` to `backend.hcl` and set  the state storage details. Each environment created needs a environments/ENV/backend.hcl file (and terraform root module etc)
1. Set Github environment conditions eg. Environment `prod-apply` Required reviewers

### Adding extra environments:

If you wish to add other environments later, replace ENVS with new ones to create and run the above steps 1 and 2. Then follow the above Next steps.

## Script details

### setup-azure-tfstate-store.sh

This creates resource groups, storage accounts (tfstate, tfplans containers) and plan/apply user managed identities for each .env item in ENVS array. Identities are granted subscription 'Contributor' and storage account 'Storage Blob Data Contributor' roles. The 'tfplans' container has a delete policy after 7 days.

⚠️NOTE: You may want to set finer permissions at the Storage container level. Storage is public, it is recommended to be used on a VNET with ACI/ACA runners.


Identity names: id-terraform-cicd-apply-$env
Storage account name: sttfstate$env$randomsuffix
Resource group: $RGPREFIX-$env


### setup-github-environments.sh

This creates the github environments (env-plan, env-apply) for each of the GITHUB_REPOS in .env file as well as federated credentials for each env in the above resource group. Variables for the repo and each environment are setup including all AZURE_ variables for terraform and azure login actions to use.

The `ADD_ENVIRONMENT_SUBJECT_CLAIM` in .env file is intentionally left off so Dependabot and Github Advanced Security can function. For an added layer of security for OIDC auth to verify federated credentials by github env, set this to true (at the cost of these features).

Federated Cred names: fic-github-$reponame-plan/apply-$env
OIDC subject scope: repo owner id, repo id, job_workflow_ref (id of tf-apply.yml/tf-plan.yml workflows), (optional) environment

### setup-github-oidc-subject.sh

This modifies the default GitHub OIDC subject sent to azure to include the 'environment' claim (GitHub environment)
