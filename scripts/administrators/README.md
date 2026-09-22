# Administrator setup

These script allow setup in Azure / Github for multiple environment terraform state and plan storage as well as user managed identities that GitHub can use to access storage and deploy terraform. You can adjust which environments to setup and add more/re-run later. There are 2 github environments per target environment allowing separate control over terraform plan and apply.

See the notes on the [setup-github-environments.sh](#setup-github-environmentssh) before running the next steps.

To setup, copy `.env.example` to `.env`, fill in the values then run:

1. setup-azure-tfstate-store.sh
1. setup-github-environments.sh
1. setup-github-oidc-subject.sh

## setup-azure-tfstate-store.sh

This creates resource groups, storage accounts (tfstate, tfplans containers) and plan/apply user managed identities for each .env item in ENVS array. Identities are granted subscription 'Contributor' and storage 'Storage Blob Data Contributor' roles.
tfplans continer has a delete policy after 7 days.

Identity names: id-terraform-cicd-apply-$env
Storage account name: sttfstate$env$randomsuffix
Resource group: $RGPREFIX-$env

## setup-github-environments.sh

This creates the github environments (env-plan, env-apply) for each of the GITHUB_REPOS in .env file as well as federated credentials for each env in the above resource group. Variables for the repo and each environment are setup including all AZURE_ variables for terraform and azure login actions to use.

The `ADD_ENVIRONMENT_SUBJECT_CLAIM` in .env file is intentionally left off so Dependabot and Github Advanced Security can function. For an added layer of security for OIDC auth to verify federated credentials by github env, set this to true (at the cost of these features).

Federated Cred names: fic-github-$reponame-plan/apply-$env
OIDC subject scope: repo owner id, repo id, job_workflow_ref (id of tf-apply.yml/tf-plan.yml workflows), (optional) environment

## setup-github-oidc-subject.sh

This modifies the default GitHub OIDC subject sent to azure to include the 'environment' claim (GitHub environment)
