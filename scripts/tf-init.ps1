# Wrapper for `terraform init` that picks up this environment's backend.hcl.
# Copy this file alongside backend.hcl into each environments/<name>/ folder.

$ErrorActionPreference = "Stop"

$TargetDir = (Get-Location).Path
$BackendFile = Join-Path $TargetDir "backend.hcl"

if (-not (Test-Path $BackendFile)) {
    Write-Error "backend.hcl not found in $TargetDir"
    exit 1
}

terraform -chdir="$TargetDir" init -backend-config="$BackendFile" @args
exit $LASTEXITCODE
