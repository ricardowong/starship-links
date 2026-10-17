# Shell startup for PowerShell 7. Twin of init.zsh: keep both in sync.
# Prints the banner, sets GH_USER / CLAUDE_USER / AG_USER for the prompt links,
# starts starship and loads the prompt link hook. Reads local files only: no network.
# The user values carry no spaces because they end up in URLs.
# Set STARSHIP_LINKS_QUIET=1 to skip the banner. The env vars are still set.

if (-not $env:STARSHIP_CONFIG) { $env:STARSHIP_CONFIG = Join-Path (Split-Path $PSScriptRoot) 'starship.toml' }
$StarshipLinksQuiet = $env:STARSHIP_LINKS_QUIET -eq '1'

$IconGitHub = [char]0xF09B
$IconClaude = [char]0xF069
$IconAg     = [char]::ConvertFromUtf32(0xF0AE2)
$IconError  = [char]0xF00D
$IconTerm   = [char]0xE795

function Write-BannerLine([string]$Icon, [string]$Label, [string]$Text, [Diagnostics.Stopwatch]$Timer, [string]$Color) {
    if ($StarshipLinksQuiet) { return }
    Write-Host ("  {0}  {1,-17}::  {2} ({3}ms)" -f $Icon, $Label, $Text, $Timer.ElapsedMilliseconds) -ForegroundColor $Color
}

if (-not $StarshipLinksQuiet) {
    Clear-Host
    Write-Host " $IconTerm  Initializing Dev Environment " -BackgroundColor Cyan -ForegroundColor Black
    Write-Host ""
}

$GitEmail = git config --global user.email 2>$null

# --- 1. GITHUB CLI: login from gh's hosts.yml (GH_USER = login#email) ---
$Timer = [Diagnostics.Stopwatch]::StartNew()
$GhHosts = Join-Path $(if ($env:GH_CONFIG_DIR) { $env:GH_CONFIG_DIR } else { "$env:APPDATA\GitHub CLI" }) 'hosts.yml'
Remove-Item Env:\GH_USER -ErrorAction SilentlyContinue
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-BannerLine $IconError 'GitHub Account' 'gh CLI Not Found' $Timer DarkGray
} elseif ((Get-Content $GhHosts -Raw -ErrorAction SilentlyContinue) -match '(?m)^\s+user:\s*(\S+)') {
    $GhLogin = $Matches[1]
    $env:GH_USER = if ($GitEmail) { "$GhLogin#$GitEmail" } else { $GhLogin }
    Write-BannerLine $IconGitHub 'GitHub Account' ($GhLogin + $(if ($GitEmail) { " - $GitEmail" })) $Timer Green
} else {
    Write-BannerLine $IconError 'GitHub Account' 'Not Authenticated' $Timer Red
}

# --- 2. CLAUDE CLI: email from ~/.claude.json (CLAUDE_USER = name/email) ---
$Timer = [Diagnostics.Stopwatch]::StartNew()
Remove-Item Env:\CLAUDE_USER -ErrorAction SilentlyContinue
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-BannerLine $IconError 'Claude CLI' 'Not Installed' $Timer DarkGray
} elseif ((Get-Content "$HOME\.claude.json" -Raw -ErrorAction SilentlyContinue) -match '"emailAddress"\s*:\s*"([^"]+)"') {
    $ClaudeEmail = $Matches[1]
    $env:CLAUDE_USER = "$(($ClaudeEmail -split '@')[0])/$ClaudeEmail"
    Write-BannerLine $IconClaude 'Claude CLI' "$(($ClaudeEmail -split '@')[0]) - $ClaudeEmail" $Timer Green
} else {
    Write-BannerLine $IconError 'Claude CLI' 'Not Authenticated' $Timer Red
}

# --- 3. ANTIGRAVITY CLI: active account from ~/.gemini (AG_USER = name/email) ---
$Timer = [Diagnostics.Stopwatch]::StartNew()
Remove-Item Env:\AG_USER, Env:\GEMINI_USER -ErrorAction SilentlyContinue
if (-not ((Get-Command agy, antigravity -ErrorAction SilentlyContinue) -or (Test-Path "$HOME\.gemini\antigravity-cli"))) {
    Write-BannerLine $IconError 'Antigravity CLI' 'Not Installed' $Timer DarkGray
} else {
    $AgEmail = if ((Get-Content "$HOME\.gemini\google_accounts.json" -Raw -ErrorAction SilentlyContinue) -match '"active"\s*:\s*"([^"]+)"') { $Matches[1] }
    if (-not $AgEmail -and ((Test-Path "$HOME\.gemini\oauth_creds.json") -or (Test-Path "$HOME\.gemini\antigravity-cli\settings.json"))) {
        $AgEmail = if ($GitEmail) { $GitEmail } else { $env:USERNAME }
    }
    if ($AgEmail) {
        $AgShort = ($AgEmail -split '@')[0]
        $env:AG_USER = if ($AgEmail -match '@') { "$AgShort/$AgEmail" } else { $AgEmail }
        Write-BannerLine $IconAg 'Antigravity CLI' $(if ($AgEmail -match '@') { "$AgShort - $AgEmail" } else { $AgEmail }) $Timer Green
    } else {
        Write-BannerLine $IconError 'Antigravity CLI' 'Not Authenticated' $Timer Red
    }
}

# --- 4. STARSHIP + PROMPT LINK HOOK ---
$Timer = [Diagnostics.Stopwatch]::StartNew()
Invoke-Expression (& starship init powershell)
. "$PSScriptRoot\prompt.ps1"
Write-BannerLine $IconTerm 'Starship Engine' 'Ready' $Timer Yellow
if (-not $StarshipLinksQuiet) { Write-Host "" }
