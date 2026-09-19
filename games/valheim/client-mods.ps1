<#
.SYNOPSIS
  Installs, disables or removes Valheim client mods on Windows.
  Actions: install (default), status, disable, enable, uninstall.
  Full instructions: docs/valheim.md, "Client mods".
.EXAMPLE
  .\client-mods.ps1
  .\client-mods.ps1 -Action disable
  .\client-mods.ps1 -GameDir "D:\Steam\steamapps\common\Valheim"
#>
[CmdletBinding()]
param(
  [ValidateSet('install', 'uninstall', 'disable', 'enable', 'status')]
  [string]$Action = 'install',

  [string]$GameDir,

  # Pinned to the versions this was tested against; -UseLatest asks
  # Thunderstore for the newest instead.
  [string]$BepInExVersion = '5.4.2350',
  [string]$DevcommandsVersion = '1.113.0',
  [switch]$UseLatest,

  # Allows uninstall to proceed when other mods are present.
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Step { param($m) Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "    $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "    $m" -ForegroundColor Yellow }

function Find-ValheimDir {
  if ($GameDir) {
    if (-not (Test-Path (Join-Path $GameDir 'valheim.exe'))) {
      throw "No valheim.exe in '$GameDir'."
    }
    return (Resolve-Path $GameDir).Path
  }

  $steam = $null
  foreach ($key in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
    try {
      $p = Get-ItemProperty -Path $key -ErrorAction Stop
      $steam = if ($p.SteamPath) { $p.SteamPath } else { $p.InstallPath }
      if ($steam) { break }
    } catch { }
  }
  if (-not $steam) { throw "Steam not found in the registry. Pass -GameDir." }

  # Games may live in any Steam library, not just the default one.
  $libraries = @($steam)
  $vdf = [IO.Path]::Combine($steam, 'steamapps', 'libraryfolders.vdf')
  if (Test-Path $vdf) {
    foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"(.+?)"')) {
      $libraries += $m.Groups[1].Value -replace '\\\\', '\'
    }
  }

  foreach ($lib in ($libraries | Select-Object -Unique)) {
    $candidate = [IO.Path]::Combine($lib, 'steamapps', 'common', 'Valheim')
    if (Test-Path (Join-Path $candidate 'valheim.exe')) { return (Resolve-Path $candidate).Path }
  }
  throw "Valheim not found in any Steam library. Pass -GameDir."
}

function Get-ThunderstoreUrl {
  param($Namespace, $Name, $Version)
  if ($UseLatest) {
    $api = "https://thunderstore.io/api/experimental/package/$Namespace/$Name/"
    $latest = (Invoke-RestMethod -Uri $api).latest
    Write-Ok "$Name -> latest $($latest.version_number)"
    return $latest.download_url
  }
  Write-Ok "$Name -> pinned $Version"
  return "https://thunderstore.io/package/download/$Namespace/$Name/$Version/"
}

function Get-Package {
  param($Url, $Destination, $MustContain)
  Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
  # Refuse to touch the game directory if the download is not what we expect.
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [IO.Compression.ZipFile]::OpenRead($Destination)
  try {
    $names = $zip.Entries | ForEach-Object { $_.FullName }
    foreach ($needle in $MustContain) {
      if (-not ($names -contains $needle)) { throw "Download looks wrong: '$needle' missing from $Url" }
    }
  } finally { $zip.Dispose() }
}

function Set-DoorstopEnabled {
  param($Dir, [bool]$Enabled)
  $ini = Join-Path $Dir 'doorstop_config.ini'
  if (-not (Test-Path $ini)) { throw "BepInEx is not installed here (no doorstop_config.ini)." }
  $value = if ($Enabled) { 'true' } else { 'false' }
  (Get-Content $ini) -replace '^\s*enabled\s*=.*', "enabled = $value" | Set-Content $ini -Encoding ASCII
  return $value
}

function Get-Status {
  param($Dir)
  $ini = Join-Path $Dir 'doorstop_config.ini'
  $hasBepInEx = Test-Path ([IO.Path]::Combine($Dir, 'BepInEx', 'core', 'BepInEx.Preloader.dll'))
  $hasLoader = Test-Path (Join-Path $Dir 'winhttp.dll')
  $enabled = $false
  if (Test-Path $ini) {
    $enabled = ((Get-Content $ini | Where-Object { $_ -match '^\s*enabled\s*=' }) -join '') -match 'true'
  }
  $plugins = @()
  $pluginDir = [IO.Path]::Combine($Dir, 'BepInEx', 'plugins')
  if (Test-Path $pluginDir) { $plugins = @(Get-ChildItem $pluginDir -Filter *.dll | Select-Object -ExpandProperty Name) }
  [pscustomobject]@{
    BepInEx = $hasBepInEx; Loader = $hasLoader; Enabled = $enabled; Plugins = $plugins
  }
}

$dir = Find-ValheimDir
Write-Step "Valheim: $dir"

switch ($Action) {

  'status' {
    $s = Get-Status $dir
    # "Active" means mods will actually load: the loader is present AND switched on.
    # The doorstop 'enabled' flag alone is not enough - a half-install can have the
    # flag set with no loader on disk, which cannot load anything.
    $active = $s.BepInEx -and $s.Loader -and $s.Enabled
    Write-Host "    BepInEx installed : $($s.BepInEx)"
    Write-Host "    Loader (winhttp)  : $($s.Loader)"
    Write-Host "    Mods active       : $active"
    Write-Host "    Plugins           : $(if ($s.Plugins) { $s.Plugins -join ', ' } else { '(none)' })"
    if ($s.BepInEx -and $s.Loader -and -not $s.Enabled) { Write-Warn "Mods are installed but disabled; run -Action enable." }
    if ($s.Enabled -and (-not $s.BepInEx -or -not $s.Loader)) { Write-Warn "Doorstop is switched on but BepInEx/loader files are missing - mods will NOT load. Run -Action install to repair." }
  }

  'disable' {
    Set-DoorstopEnabled $dir $false | Out-Null
    Write-Ok "Disabled. Valheim will launch vanilla; mods stay on disk."
  }

  'enable' {
    Set-DoorstopEnabled $dir $true | Out-Null
    Write-Ok "Enabled. Valheim will launch with mods."
  }

  'install' {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("valheim-mods-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
      Write-Step "Downloading"
      $bepZip = Join-Path $tmp 'bepinex.zip'
      $devZip = Join-Path $tmp 'devcommands.zip'
      Get-Package (Get-ThunderstoreUrl 'denikson' 'BepInExPack_Valheim' $BepInExVersion) $bepZip `
        @('BepInExPack_Valheim/winhttp.dll', 'BepInExPack_Valheim/doorstop_config.ini')
      Get-Package (Get-ThunderstoreUrl 'JereKuusela' 'Server_devcommands' $DevcommandsVersion) $devZip `
        @('ServerDevcommands.dll')

      Write-Step "Installing BepInEx"
      Expand-Archive -Path $bepZip -DestinationPath ([IO.Path]::Combine($tmp, 'bep')) -Force
      # Only the inner folder belongs in the game dir; the rest is package metadata.
      Copy-Item -Path ([IO.Path]::Combine($tmp, 'bep', 'BepInExPack_Valheim', '*')) -Destination $dir -Recurse -Force
      Write-Ok "BepInEx in place"

      Write-Step "Installing Server Devcommands"
      $pluginDir = [IO.Path]::Combine($dir, 'BepInEx', 'plugins')
      New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
      Expand-Archive -Path $devZip -DestinationPath ([IO.Path]::Combine($tmp, 'dev')) -Force
      Copy-Item -Path ([IO.Path]::Combine($tmp, 'dev', 'ServerDevcommands.dll')) -Destination $pluginDir -Force
      Write-Ok "ServerDevcommands.dll in place"

      Set-DoorstopEnabled $dir $true | Out-Null
      Write-Step "Done"
      Write-Host "    Launch Valheim normally. In game press F5 and type 'devcommands'."
      Write-Host "    Your SteamID64 must be in the server's /config/adminlist.txt."
      Write-Host "    If an update breaks things: .\client-mods.ps1 -Action disable"
    } finally {
      Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  'uninstall' {
    $s = Get-Status $dir
    $foreign = @($s.Plugins | Where-Object { $_ -ne 'ServerDevcommands.dll' })
    if ($foreign -and -not $Force) {
      Write-Warn "Other mods are installed: $($foreign -join ', ')"
      Write-Warn "Removing BepInEx would break them. Re-run with -Force, or use -Action disable."
      return
    }
    Write-Step "Removing"
    foreach ($item in @('BepInEx', 'doorstop_libs', 'winhttp.dll', 'doorstop_config.ini',
                        '.doorstop_version', 'changelog.txt',
                        'start_game_bepinex.sh', 'start_server_bepinex.sh')) {
      $path = Join-Path $dir $item
      if (Test-Path $path) { Remove-Item $path -Recurse -Force; Write-Ok "removed $item" }
    }
    Write-Ok "Valheim is back to vanilla."
  }
}
