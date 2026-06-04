# Installer for claude-skills (Windows PowerShell)
# Copies all skills into %USERPROFILE%\.claude\commands\

param([switch]$Force)

$ErrorActionPreference = "Stop"

$Dest = Join-Path $env:USERPROFILE ".claude\commands"
$Src = Join-Path $PSScriptRoot "commands"

if (-not (Test-Path $Src)) {
    Write-Error "commands\ directory not found at $Src"
    exit 1
}

New-Item -ItemType Directory -Force -Path $Dest | Out-Null

$installed = 0
$skipped = 0

Get-ChildItem -Path $Src -Filter "*.md" | ForEach-Object {
    $target = Join-Path $Dest $_.Name
    if ((Test-Path $target) -and (-not $Force)) {
        $srcHash = (Get-FileHash $_.FullName).Hash
        $dstHash = (Get-FileHash $target).Hash
        if ($srcHash -ne $dstHash) {
            Write-Host ("  - {0,-24} exists with local changes - leaving as-is. Re-run with -Force to overwrite." -f $_.Name)
            $script:skipped++
            return
        }
    }
    Copy-Item $_.FullName $target -Force
    $script:installed++
}

Write-Host ""
Write-Host ("OK Installed {0} skill(s) to {1}" -f $installed, $Dest) -ForegroundColor Green
if ($skipped -gt 0) {
    Write-Host ("  {0} skipped (already present with local changes; use -Force to overwrite)" -f $skipped)
}
Write-Host ""
Write-Host "Open Claude Code and type / to see the new commands."
