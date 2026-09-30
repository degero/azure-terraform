#!/usr/bin/env pwsh
# scripts/tf-unit-test.ps1
[CmdletBinding()]
param(
    [string[]]$Path = @('modules', 'modulegroups', 'tests')
)

$ErrorActionPreference = 'Continue'

function Start-Group($name) {
    if ($env:GITHUB_ACTIONS) { Write-Host "::group::$name" }
    elseif ($env:TF_BUILD) { Write-Host "##[group]$name" }
    else { Write-Host "=== $name ===" }
}

function Stop-Group {
    if ($env:GITHUB_ACTIONS) { Write-Host "::endgroup::" }
    elseif ($env:TF_BUILD) { Write-Host "##[endgroup]" }
}

$moduleDirs = Get-ChildItem -Path $Path -Recurse -Filter '*.tftest.hcl' -File |
Where-Object {
    $_.FullName -notmatch '[\\/]\.terraform[\\/]' -and # ignore downloaded modules
    $_.FullName -notmatch '[\\/]tests[\\/][^\\/]+[\\/]'      # ignore tests/integration/ etc.
} |
ForEach-Object {
    $dir = $_.Directory
    if ($dir.Name -eq 'tests') { $dir = $dir.Parent }        # tests/ layout -> module root
    $dir.FullName
} |
Sort-Object -Unique

if (-not $moduleDirs) {
    Write-Host "No *.tftest.hcl files found under: $($Path -join ', ')"
    exit 0
}

$failed = @()

foreach ($dir in $moduleDirs) {
    $label = Resolve-Path -Path $dir -Relative
    Start-Group $label

    terraform -chdir="$dir" init -backend=false -input=false
    if ($LASTEXITCODE -ne 0) {
        $failed += "$label (init)"
    }
    else {
        terraform -chdir="$dir" test
        if ($LASTEXITCODE -ne 0) { $failed += "$label (test)" }
    }

    Stop-Group
}

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed:" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 1
}

Write-Host "All module tests passed." -ForegroundColor Green
exit 0
