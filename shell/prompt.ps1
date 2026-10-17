# Prompt link hook for starship (PowerShell 7). Twin of prompt.zsh: keep both in sync.
# Sets the STARSHIP_* env vars that starship.toml turns into links.
# It runs before every prompt, so it reads .git files directly: each git or python
# process costs ~80-300 ms on Windows. docker runs in a background job.

$global:StarshipVars = 'CWD_URI', 'GIT_ROOT', 'GIT_OWNER', 'GIT_OWNER_URL', 'GIT_REPO',
    'GIT_REPO_URL', 'GIT_BRANCHES_URL', 'GIT_TREE_URL', 'PY_URI', 'DOCKER'
$global:ComposeFiles = 'compose.yaml', 'compose.yml', 'docker-compose.yml', 'docker-compose.yaml'
$global:Osc = [char]27 + ']8;;'
$global:Bel = [char]7

function global:Invoke-Starship-PreCommand {
    foreach ($n in $global:StarshipVars) { Remove-Item "Env:STARSHIP_$n" -ErrorAction SilentlyContinue }
    if ($PWD.Provider.Name -ne 'FileSystem') { return }
    $cwd = $PWD.ProviderPath
    $env:STARSHIP_CWD_URI = ([uri]$cwd).AbsoluteUri

    $root = $cwd
    while ($root -and -not (Test-Path -LiteralPath "$root\.git")) { $root = Split-Path $root -Parent }
    if ($root) { Set-StarshipGitVars $root }
    Set-StarshipPythonVar $cwd $root
    Set-StarshipDockerVar $(if ($root) { $root } else { $cwd })
}

function global:Set-StarshipGitVars([string]$Root) {
    $env:STARSHIP_GIT_ROOT = $Root
    $gitDir = "$Root\.git"
    if (Test-Path -LiteralPath $gitDir -PathType Leaf) {
        # Worktree: .git is a file that points at .git/worktrees/<name>
        $gitDir = ((Get-Content -LiteralPath $gitDir -Raw) -replace '^gitdir:\s*', '').Trim()
        if (-not [IO.Path]::IsPathRooted($gitDir)) { $gitDir = Join-Path $Root $gitDir }
    }
    $commonDir = $gitDir
    if (Test-Path -LiteralPath "$gitDir\commondir") {
        $commonDir = Join-Path $gitDir (Get-Content -LiteralPath "$gitDir\commondir" -Raw).Trim()
    }
    $head = (Get-Content -LiteralPath "$gitDir\HEAD" -Raw -ErrorAction SilentlyContinue)
    $branch = if ($head -match '^ref: refs/heads/(\S+)') { $Matches[1] }
    $config = Get-Content -LiteralPath "$commonDir\config" -Raw -ErrorAction SilentlyContinue

    if ($config -match '(?ms)^\[remote "origin"\][^\[]*?^\s*url\s*=\s*(\S+)' -and
        $Matches[1] -match '^(?:[a-z+]+://)?(?:[^@/]+@)?([^/:]+)(?::\d+)?[:/](.+?)(?:\.git)?/?$') {
        $web = "https://$($Matches[1])"
        $path = $Matches[2]
        $owner = $path.Substring(0, [Math]::Max(0, $path.LastIndexOf('/')))
        $env:STARSHIP_GIT_OWNER = $owner
        $env:STARSHIP_GIT_OWNER_URL = "$web/$owner"
        $env:STARSHIP_GIT_REPO = $path.Substring($path.LastIndexOf('/') + 1)
        $env:STARSHIP_GIT_REPO_URL = "$web/$path"
        $env:STARSHIP_GIT_BRANCHES_URL = "$web/$path/branches"
        if ($branch) { $env:STARSHIP_GIT_TREE_URL = "$web/$path/tree/$branch" }
    } else {
        $env:STARSHIP_GIT_BRANCHES_URL = ([uri]$Root).AbsoluteUri
    }
}

function global:Set-StarshipPythonVar([string]$Cwd, [string]$Root) {
    $venv = $env:VIRTUAL_ENV
    if (-not $venv) {
        $dir = $Cwd
        while ($dir) {
            if (Test-Path -LiteralPath "$dir\.venv\pyvenv.cfg") { $venv = "$dir\.venv"; break }
            if ($dir -eq $Root) { break }
            $dir = Split-Path $dir -Parent
        }
    }
    if (-not $venv) {
        # No venv: link the folder of the python on PATH. Cached per shell, and the
        # version comes from the exe's file info, so no python process starts.
        if ($null -eq $global:StarshipSystemPython) {
            $exe = Get-Command python -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            $global:StarshipSystemPython = if ($exe) {
                ([uri](Split-Path $exe.Source)).AbsoluteUri + "#python-$($exe.FileVersionInfo.ProductVersion)"
            } else { '' }
        }
        if ($global:StarshipSystemPython) { $env:STARSHIP_PY_URI = $global:StarshipSystemPython }
        return
    }
    $cfg =Get-Content -LiteralPath "$venv\pyvenv.cfg" -Raw -ErrorAction SilentlyContinue
    $version = if ($cfg -match '(?m)^\s*version(?:_info)?\s*=\s*(\S+)') { "#python-$($Matches[1])" }
    $env:STARSHIP_PY_URI = ([uri]$venv).AbsoluteUri + $version
}

function global:Set-StarshipDockerVar([string]$Dir) {
    if (-not ($global:ComposeFiles | Where-Object { Test-Path -LiteralPath "$Dir\$_" })) { return }
    $cache = Join-Path $env:TEMP ('starship-docker-' + ($Dir -replace '\W', '_') + '.txt')
    $item = Get-Item -LiteralPath $cache -ErrorAction SilentlyContinue
    if (-not $item -or $item.LastWriteTime -lt (Get-Date).AddSeconds(-10)) {
        Get-Job -Name starship-docker -ErrorAction SilentlyContinue |
            Where-Object State -ne 'Running' | Remove-Job
        if (-not (Get-Job -Name starship-docker -ErrorAction SilentlyContinue)) {
            $null = Start-ThreadJob -Name starship-docker -ArgumentList $Dir, $cache -ScriptBlock {
                param($Dir, $Cache)
                Set-Location -LiteralPath $Dir
                $ports = docker compose ps --format '{{range .Publishers}}{{if .PublishedPort}}{{.PublishedPort}} {{end}}{{end}}' 2>$null
                Set-Content -LiteralPath $Cache -Value ("$ports" -split '\s+' | Where-Object { $_ } | Sort-Object -Unique { [int]$_ })
            }
        }
    }
    $links = if ($item) { Get-Content -LiteralPath $cache | ForEach-Object { "${global:Osc}http://localhost:$_${global:Bel}:$_${global:Osc}${global:Bel}" } }
    $env:STARSHIP_DOCKER = ' ' + (($links | ForEach-Object { "$_ " }) -join '')
}
