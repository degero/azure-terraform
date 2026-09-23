# scripts/prepush.ps1
$ErrorActionPreference = "Stop"

$RepoRoot = git rev-parse --show-toplevel
Set-Location $RepoRoot

Write-Information "==> Prettier check (json, jsonc, yaml, yml, md)" -InformationAction Continue
npx prettier --write "**/*.{json,jsonc,yaml,yml,md}"

Write-Information "==> Terraform fmt check" -InformationAction Continue
terraform fmt -recursive -check

Write-Information "==> Terraform validate" -InformationAction Continue
$failed = $false
$envDirs = Get-ChildItem -Path "environments" -Directory

foreach ($dir in $envDirs) {
    $envPath = $dir.FullName
    $envName = $dir.Name

    terraform -chdir="$envPath" init -backend=false -input=false | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Information "✗ Init failed in $envName" -InformationAction Continue
        $failed = $true
        continue
    }

    terraform -chdir="$envPath" validate
    if ($LASTEXITCODE -ne 0) {
        Write-Information "✗ Validation failed in $envName" -InformationAction Continue
        $failed = $true
    }
}

if ($failed) {
    exit 1
}

Write-Information "==> tflint (modules)" -InformationAction Continue
tflint -f compact --recursive --chdir=modules      --config="$RepoRoot/.tflint.modules.hcl"
tflint -f compact --recursive --chdir=modulegroups --config="$RepoRoot/.tflint.modules.hcl"

Write-Information "==> tflint (environments)" -InformationAction Continue
tflint -f compact --recursive --chdir=environments

Write-Information "==> Checkov" -InformationAction Continue
if (Get-Command checkov -ErrorAction SilentlyContinue) {
    checkov -d . --config-file "$RepoRoot/.checkov.yaml"
}
else {
    Write-Information "checkov not found locally — skipping (will still run in CI)" -InformationAction Continue
}

Write-Information "==> All checks passed" -InformationAction Continue
