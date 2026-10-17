# Renders your current prompt once per palette in starship.toml.
# Run it from a shell that loaded shell/init.ps1, inside a git repo, so the link
# hook has set its env vars: pwsh -File tools/preview-themes.ps1
$src = if ($env:STARSHIP_CONFIG) { $env:STARSHIP_CONFIG } else { Join-Path (Split-Path $PSScriptRoot) 'starship.toml' }
$tmp = Join-Path ([IO.Path]::GetTempPath()) 'starship-links-preview.toml'
$config = Get-Content $src -Raw
foreach ($name in [regex]::Matches($config, '\[palettes\.(\w+)\]') | ForEach-Object { $_.Groups[1].Value }) {
    $config -replace "(?m)^palette = '.*'", "palette = '$name'" | Set-Content $tmp -NoNewline
    $env:STARSHIP_CONFIG = $tmp
    Write-Host "`n  $name"
    Write-Host ('  ' + ((starship prompt) -join ''))
}
$env:STARSHIP_CONFIG = $src
Remove-Item $tmp
Write-Host ''
