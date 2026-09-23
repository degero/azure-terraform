# scripts/prepush.ps1
$ErrorActionPreference = "Stop"

$RepoRoot = git rev-parse --show-toplevel
Set-Location $RepoRoot

Write-Host "==> Prettier check (json, jsonc, yaml, yml, md)"
npx prettier --write "**/*.{json,jsonc,yaml,yml,md}"

Write-Host "==> Terraform fmt check"
terraform fmt -recursive -check

Write-Host "==> Terraform validate"
$failed = $false
Get-ChildItem -Path "environments" -Directory | ForEach-Object {
    $envPath = $_.FullName
    $envName = $_.Name

    terraform -chdir="$envPath" init -backend=false -input=false | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Init failed in $envName"
        $failed = $true
        return
    }

    terraform -chdir="$envPath" validate
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Validation failed in $envName"
        $failed = $true
    }
}

if ($failed) {
    exit 1
}

Write-Host "==> tflint (modules)"
tflint -f compact --recursive --chdir=modules      --config="$RepoRoot/.tflint.modules.hcl"
tflint -f compact --recursive --chdir=modulegroups --config="$RepoRoot/.tflint.modules.hcl"

Write-Host "==> tflint (environments)"
tflint -f compact --recursive --chdir=environments

Write-Host "==> Checkov"
if (Get-Command checkov -ErrorAction SilentlyContinue) {
    checkov -d . --config-file "$RepoRoot/.checkov.yaml"
}
else {
    Write-Host "checkov not found locally — skipping (will still run in CI)"
}

Write-Host "==> All checks passed"
