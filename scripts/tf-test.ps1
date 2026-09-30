#!/usr/bin/env pwsh
# scripts/tf-test.ps1
[CmdletBinding()]
param(
    [string[]]$Path = @('modules', 'modulegroups', 'tests')
)

$ErrorActionPreference = 'Continue'
$InformationPreference = 'Continue'

function Enter-LogGroup {
    param([string]$Name)
    if ($env:GITHUB_ACTIONS) { Write-Information "::group::$Name" }
    elseif ($env:TF_BUILD) { Write-Information "##[group]$Name" }
    else { Write-Information "=== $Name ===" }
}

function Exit-LogGroup {
    if ($env:GITHUB_ACTIONS) { Write-Information "::endgroup::" }
    elseif ($env:TF_BUILD) { Write-Information "##[endgroup]" }
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
    Write-Information "No *.tftest.hcl files found under: $($Path -join ', ')"
    exit 0
}

$failed = @()

foreach ($dir in $moduleDirs) {
    $label = Resolve-Path -Path $dir -Relative
    Enter-LogGroup $label

    terraform -chdir="$dir" init -backend=false -input=false
    if ($LASTEXITCODE -ne 0) {
        $failed += "$label (init)"
    }
    else {
        terraform -chdir="$dir" test
        if ($LASTEXITCODE -ne 0) { $failed += "$label (test)" }
    }

    Exit-LogGroup
}

if ($failed.Count -gt 0) {
    Write-Information ""
    Write-Information "Failed:"
    $failed | ForEach-Object { Write-Information "  $_" }
    exit 1
}

Write-Information "All module tests passed."
exit 0
