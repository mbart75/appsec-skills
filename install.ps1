<#
.SYNOPSIS
    Installs the appsec-* skills into the AI coding agents present on this machine (Windows, macOS, Linux).

.DESCRIPTION
    Without parameters, shows a menu of known agents (detected ones are marked) and asks for confirmation.
    Only folders named appsec-* are created, replaced or removed. No network, no elevation.

.EXAMPLE
    ./install.ps1
.EXAMPLE
    ./install.ps1 -Agents claude,codex -Yes
.EXAMPLE
    ./install.ps1 -AllDetected -DryRun
.EXAMPLE
    ./install.ps1 -Agents codex -Uninstall -Yes
#>
# Interactive installer: writing to the console is the point, so Write-Host is intended.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
[CmdletBinding()]
param(
    [string[]]$Agents,
    [switch]$AllDetected,
    [string[]]$Dir,
    [string[]]$Skills,
    [switch]$Uninstall,
    [switch]$DryRun,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'skills'
if (-not (Test-Path $source)) { throw "No skills folder next to this script. Run it from the unzipped release or a clone." }

$catalogue = @(
    @{ Key = 'claude';   Name = 'Claude Code';                          Config = '.claude';          Folder = '.claude/skills' }
    @{ Key = 'codex';    Name = 'Codex';                                Config = '.codex';           Folder = '.codex/skills' }
    @{ Key = 'cursor';   Name = 'Cursor';                               Config = '.cursor';          Folder = '.cursor/skills' }
    @{ Key = 'copilot';  Name = 'GitHub Copilot CLI';                   Config = '.copilot';         Folder = '.copilot/skills' }
    @{ Key = 'gemini';   Name = 'Gemini CLI';                           Config = '.gemini';          Folder = '.gemini/skills' }
    @{ Key = 'opencode'; Name = 'OpenCode';                             Config = '.config/opencode'; Folder = '.config/opencode/skills' }
    @{ Key = 'agents';   Name = 'Shared folder read by several agents'; Config = '.agents';          Folder = '.agents/skills' }
)
foreach ($entry in $catalogue) {
    $entry.ConfigPath = Join-Path $HOME $entry.Config
    $entry.FolderPath = Join-Path $HOME $entry.Folder
}

$available = @(Get-ChildItem -Path $source -Directory -Filter 'appsec-*' |
    Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } |
    ForEach-Object { $_.Name })
if ($available.Count -eq 0) { throw "No appsec-* skill found in $source" }

# Accept both -Agents claude,codex and -Agents 'claude,codex' (the form pwsh -File passes).
$Agents = @($Agents | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Skills = @($Skills | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
foreach ($key in $Agents) {
    if (-not ($catalogue | Where-Object { $_.Key -eq $key })) {
        throw "Unknown agent: $key (known: $(($catalogue | ForEach-Object { $_.Key }) -join ', '))"
    }
}

if ($Skills) {
    foreach ($skill in $Skills) {
        if ($available -notcontains $skill) { throw "Unknown skill: $skill (available: $($available -join ', '))" }
    }
    $chosenSkills = $Skills
} else {
    $chosenSkills = $available
}

$targets = [System.Collections.Generic.List[object]]::new()
foreach ($key in $Agents) {
    $entry = $catalogue | Where-Object { $_.Key -eq $key }
    $targets.Add([pscustomobject]@{ Name = $entry.Name; Folder = $entry.FolderPath })
}
foreach ($path in $Dir) { $targets.Add([pscustomobject]@{ Name = 'Custom folder'; Folder = $path }) }
if ($AllDetected) {
    foreach ($entry in $catalogue | Where-Object { Test-Path $_.ConfigPath }) {
        $targets.Add([pscustomobject]@{ Name = $entry.Name; Folder = $entry.FolderPath })
    }
}

if ($targets.Count -eq 0) {
    Write-Host 'Which AI agents do you use? Detected ones are marked with *.'
    for ($i = 0; $i -lt $catalogue.Count; $i++) {
        $mark = if (Test-Path $catalogue[$i].ConfigPath) { '*' } else { ' ' }
        Write-Host ("  {0}) {1} {2}   ({3})" -f ($i + 1), $mark, $catalogue[$i].Name, $catalogue[$i].FolderPath)
    }
    Write-Host '  c) Another folder (you type its path)'
    $answer = Read-Host 'Numbers separated by spaces, or Enter for all detected'
    if ([string]::IsNullOrWhiteSpace($answer)) {
        foreach ($entry in $catalogue | Where-Object { Test-Path $_.ConfigPath }) {
            $targets.Add([pscustomobject]@{ Name = $entry.Name; Folder = $entry.FolderPath })
        }
    } else {
        foreach ($choice in ($answer -split '\s+' | Where-Object { $_ })) {
            if ($choice -eq 'c') {
                $custom = Read-Host 'Path of the skills folder'
                $targets.Add([pscustomobject]@{ Name = 'Custom folder'; Folder = $custom })
            } elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $catalogue.Count) {
                $entry = $catalogue[[int]$choice - 1]
                $targets.Add([pscustomobject]@{ Name = $entry.Name; Folder = $entry.FolderPath })
            } else {
                throw "Invalid choice: $choice"
            }
        }
    }
}
if ($targets.Count -eq 0) { throw 'No agent detected. Choose one with -Agents or -Dir.' }

$action = if ($Uninstall) { 'uninstall' } else { 'install' }
Write-Host ''
Write-Host "Plan ($action, mode: copy):"
foreach ($target in $targets) {
    Write-Host "  $($target.Name) -> $($target.Folder)"
    foreach ($skill in $chosenSkills) { Write-Host "      $skill" }
}
if ($DryRun) { Write-Host '(dry run: nothing changed)'; return }
if (-not $Yes) {
    $ok = Read-Host 'Proceed? [y/N]'
    if ($ok -notmatch '^(y|yes|o|oui)$') { Write-Host 'Nothing changed.'; return }
}

foreach ($target in $targets) {
    if (-not $Uninstall) { New-Item -ItemType Directory -Path $target.Folder -Force | Out-Null }
    foreach ($skill in $chosenSkills) {
        if ($skill -notlike 'appsec-*') { throw "Refusing to touch a non appsec-* folder: $skill" }
        $destination = Join-Path $target.Folder $skill
        # -LiteralPath: folder names may contain [ ] which -Path treats as wildcards.
        $existing = Get-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
        if ($existing) {
            if ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                # A link or junction: remove the link itself, never what it points to
                # (Windows PowerShell 5.1 can empty the target with Remove-Item -Recurse).
                $existing.Delete()
            } else {
                Remove-Item -LiteralPath $destination -Recurse -Force
            }
        }
        if ($Uninstall) {
            if ($existing) { Write-Host "  removed $destination" }
        } else {
            Copy-Item -LiteralPath (Join-Path $source $skill) -Destination $destination -Recurse
            Write-Host "  $skill -> $destination"
        }
    }
}

Write-Host ''
if ($Uninstall) {
    Write-Host 'Done.'
} else {
    Write-Host 'Done. Restart your agent, then try:  Use appsec-review in full mode on this repository.'
    Write-Host 'To update later: download the new release and run this script again.'
}
