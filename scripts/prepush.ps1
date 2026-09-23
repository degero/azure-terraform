# scripts/prepush.ps1
$ErrorActionPreference = "Stop"

$RepoRoot = git rev-parse --show-toplevel
Set-Location $RepoRoot

Write-Host "==> Prettier check (json, jsonc, yaml, yml, md)"
npx prettier --write "**/*.{json,jsonc,yaml,yml,md}"

Write-Host "==> Terraform fmt check"
terraform fmt -recursive -check

Write-Host "==> tflint (modules)"
tflint -f compact --recursive --chdir=modules     --config="$RepoRoot/.tflint.modules.hcl"
tflint -f compact --recursive --chdir=modulegroup --config="$RepoRoot/.tflint.modules.hcl"

Write-Host "==> tflint (environments)"
tflint -f compact --recursive --chdir=environments

Write-Host "==> Checkov"
checkov -d . --config-file "$RepoRoot/.checkov.yaml"

Write-Host "==> All checks passed"
