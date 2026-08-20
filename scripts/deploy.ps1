<#
.SYNOPSIS
    Management script for cjk-token-reducer on Windows (install, uninstall, status).

.DESCRIPTION
    Installs/uninstalls cjk-token-reducer binary and configures Claude Code hooks on Windows.

.PARAMETER Action
    Command to execute: 'install', 'uninstall', 'status', or 'help'.

.EXAMPLE
    .\scripts\deploy.ps1 install
    .\scripts\deploy.ps1 uninstall
    .\scripts\deploy.ps1 status
#>

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [ValidateSet("install", "uninstall", "status", "help")]
    [string]$Action = "help"
)

$ErrorActionPreference = "Stop"

# Color helpers
function Write-InfoMessage([string]$Message) {
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-WarnMessage([string]$Message) {
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-ErrorMessage([string]$Message) {
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-StatusMessage([string]$Message) {
    Write-Host "[STATUS] $Message" -ForegroundColor Cyan
}

function Show-Usage {
    Write-Host "Usage: .\scripts\deploy.ps1 [install|uninstall|status|help]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  install   - Install cjk-token-reducer and configure Claude Code hooks"
    Write-Host "  uninstall - Remove cjk-token-reducer and Claude Code hooks"
    Write-Host "  status    - Show installation status"
    Write-Host "  help      - Show this help message"
}

# Determine install directory on Windows
function Get-InstallDirectory {
    if ($env:LOCALAPPDATA) {
        return Join-Path $env:LOCALAPPDATA "cjk-token-reducer"
    }
    return Join-Path $env:USERPROFILE ".local\bin"
}

# Find built or downloaded binary
function Find-SourceBinary {
    $candidates = @(
        ".\target\release\cjk-token-reducer.exe",
        ".\target\x86_64-pc-windows-msvc\release\cjk-token-reducer.exe",
        ".\artifacts\cjk-token-reducer-windows-x86_64.exe",
        ".\cjk-token-reducer.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }
    return $null
}

# Check if Claude CLI is installed
function Test-ClaudeCli {
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeCmd) {
        Write-WarnMessage "Claude CLI not found in PATH"
        Write-Host ""
        Write-Host "Please install Claude Code first:"
        Write-Host "  npm install -g @anthropic-ai/claude-code"
        Write-Host ""
        return $false
    }
    Write-InfoMessage "Claude CLI found: $($claudeCmd.Source)"
    return $true
}

# Ensure directory exists
function Ensure-Directory([string]$Path) {
    if (-not (Test-Path $Path)) {
        Write-InfoMessage "Creating directory: $Path"
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

# Add folder to User PATH if not already present
function Add-ToUserPath([string]$Dir) {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $paths = ($userPath -split ";") | Where-Object { $_ -ne "" }

    if ($paths -contains $Dir) {
        Write-InfoMessage "Install directory is already in User PATH"
        return
    }

    try {
        $newPath = "$userPath;$Dir"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        $env:Path = "$env:Path;$Dir"
        Write-InfoMessage "Added $Dir to User PATH"
    } catch {
        Write-WarnMessage "Failed to automatically update User PATH: $_"
        Write-Host "Please manually add '$Dir' to your PATH environment variable."
    }
}

# Remove folder from User PATH
function Remove-FromUserPath([string]$Dir) {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $userPath) { return }

    $paths = ($userPath -split ";") | Where-Object { $_ -ne "" -and $_ -ne $Dir }
    $newPath = $paths -join ";"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
}

# Check if PATH contains directory
function Test-PathInEnv([string]$Dir) {
    $envPaths = ($env:Path -split ";") | Where-Object { $_ -ne "" }
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $userPaths = ($userPath -split ";") | Where-Object { $_ -ne "" }

    if (($envPaths -contains $Dir) -or ($userPaths -contains $Dir)) {
        Write-InfoMessage "Install directory is in PATH: $Dir"
        return $true
    } else {
        Write-WarnMessage "Install directory is not in PATH: $Dir"
        return $false
    }
}

# Configure Claude Code hook in settings.json
function Set-ClaudeHook([string]$BinaryPath) {
    $claudeDir = Join-Path $env:USERPROFILE ".claude"
    $settingsFile = Join-Path $claudeDir "settings.json"
    $backupFile = Join-Path $claudeDir "settings.json.backup"

    Ensure-Directory $claudeDir

    $settings = [PSCustomObject]@{}
    if (Test-Path $settingsFile) {
        try {
            Write-InfoMessage "Creating backup of existing settings.json"
            Copy-Item -Path $settingsFile -Destination $backupFile -Force
            $rawContent = Get-Content -Path $settingsFile -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($rawContent)) {
                $settings = $rawContent | ConvertFrom-Json
            }
        } catch {
            Write-WarnMessage "Could not parse existing settings.json, creating a new structure."
            $settings = [PSCustomObject]@{}
        }
    }

    # Normalize binary path for JSON (use forward slashes)
    $normalizedBinPath = $BinaryPath.Replace("\", "/")

    # Ensure hooks object exists
    if (-not ($settings.PSObject.Properties.Name -contains "hooks") -or ($null -eq $settings.hooks)) {
        $settings | Add-Member -NotePropertyName "hooks" -NotePropertyValue ([PSCustomObject]@{}) -Force
    }

    # Ensure UserPromptSubmit array exists
    if (-not ($settings.hooks.PSObject.Properties.Name -contains "UserPromptSubmit") -or ($null -eq $settings.hooks.UserPromptSubmit)) {
        $settings.hooks | Add-Member -NotePropertyName "UserPromptSubmit" -NotePropertyValue @() -Force
    }

    # Check if hook already exists
    $existing = $false
    foreach ($entry in $settings.hooks.UserPromptSubmit) {
        if ($entry.hooks) {
            foreach ($h in $entry.hooks) {
                if ($h.command -like "*cjk-token-reducer*") {
                    $existing = $true
                    break
                }
            }
        }
    }

    if ($existing) {
        Write-InfoMessage "Claude hook is already configured in $settingsFile"
        return
    }

    # Construct new hook object
    $hookItem = [PSCustomObject]@{
        type    = "command"
        command = $normalizedBinPath
    }
    $hookGroup = [PSCustomObject]@{
        hooks = @($hookItem)
    }

    $currentList = [System.Collections.ArrayList]@($settings.hooks.UserPromptSubmit)
    [void]$currentList.Add($hookGroup)
    $settings.hooks.UserPromptSubmit = $currentList.ToArray()

    $jsonStr = $settings | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($settingsFile, $jsonStr, [System.Text.Encoding]::UTF8)

    Write-InfoMessage "Hook configured successfully in $settingsFile"
}

# Remove Claude Code hook from settings.json
function Remove-ClaudeHook {
    $claudeDir = Join-Path $env:USERPROFILE ".claude"
    $settingsFile = Join-Path $claudeDir "settings.json"
    $backupFile = Join-Path $claudeDir "settings.json.before-uninstall"

    if (-not (Test-Path $settingsFile)) {
        Write-WarnMessage "Claude settings file not found: $settingsFile"
        return
    }

    try {
        Copy-Item -Path $settingsFile -Destination $backupFile -Force
        $rawContent = Get-Content -Path $settingsFile -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($rawContent)) { return }
        $settings = $rawContent | ConvertFrom-Json
    } catch {
        Write-ErrorMessage "Failed to read settings.json: $_"
        return
    }

    if ($settings.hooks -and $settings.hooks.UserPromptSubmit) {
        $filtered = @()
        foreach ($entry in $settings.hooks.UserPromptSubmit) {
            if ($entry.hooks) {
                $keptHooks = @($entry.hooks | Where-Object { $_.command -notlike "*cjk-token-reducer*" })
                if ($keptHooks.Count -gt 0) {
                    $entry.hooks = $keptHooks
                    $filtered += $entry
                }
            } else {
                $filtered += $entry
            }
        }

        if ($filtered.Count -gt 0) {
            $settings.hooks.UserPromptSubmit = $filtered
        } else {
            $settings.hooks.PSObject.Properties.Remove("UserPromptSubmit")
        }

        if ($settings.hooks.PSObject.Properties.Count -eq 0) {
            $settings.PSObject.Properties.Remove("hooks")
        }

        $jsonStr = $settings | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($settingsFile, $jsonStr, [System.Text.Encoding]::UTF8)
        Write-InfoMessage "Hook removed from $settingsFile"
    }
}

# Installation Flow
function Perform-Install {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  cjk-token-reducer Windows Installer" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""

    # Check for Claude CLI
    $hasClaude = Test-ClaudeCli

    # Find source binary
    $sourceBin = Find-SourceBinary
    if (-not $sourceBin) {
        Write-ErrorMessage "Binary cjk-token-reducer.exe not found."
        Write-Host ""
        Write-Host "Please build the binary first:"
        Write-Host "  cargo build --release"
        Write-Host "Or download 'cjk-token-reducer-windows-x86_64.exe' from GitHub Releases."
        Write-Host ""
        exit 1
    }

    $installDir = Get-InstallDirectory
    Ensure-Directory $installDir

    $targetBin = Join-Path $installDir "cjk-token-reducer.exe"
    Write-InfoMessage "Installing binary from $sourceBin to $targetBin"
    Copy-Item -Path $sourceBin -Destination $targetBin -Force

    if (-not (Test-Path $targetBin)) {
        Write-ErrorMessage "Binary installation failed."
        exit 1
    }
    Write-InfoMessage "Binary installed successfully."

    # Add to User PATH
    Add-ToUserPath $installDir

    # Configure hook
    Set-ClaudeHook -BinaryPath $targetBin

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "  Installation Complete" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Binary installed to: $targetBin"
    Write-Host "Claude hook configured in: $env:USERPROFILE\.claude\settings.json"
    Write-Host ""
    Write-Host "Restart your terminal / PowerShell to apply PATH changes."
    Write-Host "You can now use cjk-token-reducer with Claude Code!"
    Write-Host ""
}

# Uninstallation Flow
function Perform-Uninstall {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  cjk-token-reducer Windows Uninstaller" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""

    $confirm = Read-Host "Are you sure you want to uninstall cjk-token-reducer? (y/N)"
    if ($confirm -notmatch "^[Yy]$") {
        Write-Host "Uninstallation cancelled."
        return
    }

    $installDir = Get-InstallDirectory
    $targetBin = Join-Path $installDir "cjk-token-reducer.exe"

    # Remove hook
    Remove-ClaudeHook

    # Remove binary
    if (Test-Path $targetBin) {
        Write-InfoMessage "Removing binary: $targetBin"
        Remove-Item -Path $targetBin -Force
    }

    # Remove directory if empty
    if ((Test-Path $installDir) -and ((Get-ChildItem $installDir).Count -eq 0)) {
        Remove-Item -Path $installDir -Force
    }

    # Remove PATH
    Remove-FromUserPath $installDir

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "  Uninstallation Complete" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "To completely remove cached data and configs:"
    Write-Host "  Remove-Item -Recurse -Force `"$env:LOCALAPPDATA\cjk-token-reducer`""
    Write-Host "  Remove-Item -Recurse -Force `"$env:APPDATA\cjk-token-reducer`""
    Write-Host ""
}

# Status Check Flow
function Check-Status {
    $installDir = Get-InstallDirectory
    $targetBin = Join-Path $installDir "cjk-token-reducer.exe"

    Write-StatusMessage "Checking installation status on Windows..."

    # Check binary
    if (Test-Path $targetBin) {
        Write-InfoMessage "Binary is installed at: $targetBin"
    } else {
        Write-WarnMessage "Binary is not installed at: $targetBin"
    }

    # Check Claude CLI
    Test-ClaudeCli | Out-Null

    # Check PATH
    Test-PathInEnv $installDir | Out-Null

    # Check Claude settings
    $settingsFile = Join-Path $env:USERPROFILE ".claude\settings.json"
    if (Test-Path $settingsFile) {
        $raw = Get-Content -Path $settingsFile -Raw -Encoding UTF8
        if ($raw -match "cjk-token-reducer") {
            Write-InfoMessage "Claude hook is configured in: $settingsFile"
        } else {
            Write-WarnMessage "Claude hook is not configured in: $settingsFile"
        }
    } else {
        Write-WarnMessage "Claude settings file does not exist: $settingsFile"
    }
}

# Dispatch Action
switch ($Action.ToLower()) {
    "install"   { Perform-Install }
    "uninstall" { Perform-Uninstall }
    "status"    { Check-Status }
    "help"      { Show-Usage }
    default     { Show-Usage }
}
