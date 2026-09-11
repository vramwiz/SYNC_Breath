$ErrorActionPreference = 'Stop'

$packageName = 'SYNC_Breath'
$pluginDir = 'C:\ProgramData\aviutl2\Plugin\SYNC_Breath'
$pluginFile = Join-Path $pluginDir 'SYNC_Breath.auf2'
$debugDll = Join-Path $pluginDir 'SYNC_Breath.dll'
$debugSymbols = Join-Path $pluginDir 'SYNC_Breath.rsm'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$readmeFile = Join-Path $projectRoot 'README.md'
$workDir = Join-Path $PSScriptRoot $packageName
$zipFile = Join-Path $PSScriptRoot "$packageName.zip"

if (-not (Test-Path -LiteralPath $pluginFile -PathType Leaf)) {
  Write-Host 'Filter plugin not found:'
  Write-Host "  $pluginFile"
  Write-Host 'Build the Release configuration first, then run this batch again.'
  exit 1
}

$pluginInfo = Get-Item -LiteralPath $pluginFile
if ($pluginInfo.Length -lt 1024) {
  Write-Host 'Filter plugin is too small to be a valid PE file:'
  Write-Host "  $pluginFile ($($pluginInfo.Length) bytes)"
  exit 1
}

$pluginStream = [System.IO.File]::OpenRead($pluginFile)
try {
  $mz0 = $pluginStream.ReadByte()
  $mz1 = $pluginStream.ReadByte()
}
finally {
  $pluginStream.Dispose()
}
if ($mz0 -ne 0x4D -or $mz1 -ne 0x5A) {
  Write-Host 'Filter plugin does not have a valid PE header:'
  Write-Host "  $pluginFile"
  exit 1
}

if ((Test-Path -LiteralPath $debugDll -PathType Leaf) -or
    (Test-Path -LiteralPath $debugSymbols -PathType Leaf)) {
  Write-Host 'Debug build files remain in the plugin directory.'
  Write-Host 'Build the Release configuration first, then run this batch again.'
  Write-Host "  $pluginDir"
  exit 1
}

if (-not (Test-Path -LiteralPath $readmeFile -PathType Leaf)) {
  Write-Host 'README not found:'
  Write-Host "  $readmeFile"
  exit 1
}

$readmeText = Get-Content -LiteralPath $readmeFile -Raw
if ($readmeText -notmatch '(?m)^#\s+SYNC_Breath\s*$') {
  Write-Host 'README does not describe SYNC_Breath:'
  Write-Host "  $readmeFile"
  exit 1
}

$setupRoot = [System.IO.Path]::GetFullPath($PSScriptRoot +
  [System.IO.Path]::DirectorySeparatorChar)
$resolvedWorkDir = [System.IO.Path]::GetFullPath($workDir)
$resolvedZipFile = [System.IO.Path]::GetFullPath($zipFile)
if (-not $resolvedWorkDir.StartsWith($setupRoot,
    [System.StringComparison]::OrdinalIgnoreCase) -or
    -not $resolvedZipFile.StartsWith($setupRoot,
    [System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'Package output escaped the Setup directory.'
}

if (Test-Path -LiteralPath $resolvedWorkDir) {
  Remove-Item -LiteralPath $resolvedWorkDir -Recurse -Force
}
if (Test-Path -LiteralPath $resolvedZipFile) {
  Remove-Item -LiteralPath $resolvedZipFile -Force
}

try {
  New-Item -ItemType Directory -Path $resolvedWorkDir -Force | Out-Null
  Copy-Item -LiteralPath $pluginFile -Destination $resolvedWorkDir -Force
  Copy-Item -LiteralPath $readmeFile -Destination $resolvedWorkDir -Force
  Compress-Archive -Path $resolvedWorkDir -DestinationPath $resolvedZipFile -Force

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedZipFile)
  try {
    $entryNames = @($archive.Entries | ForEach-Object {
      $_.FullName.Replace('\', '/')
    })
    foreach ($requiredEntry in @(
      "$packageName/$packageName.auf2",
      "$packageName/README.md"
    )) {
      if ($entryNames -notcontains $requiredEntry) {
        throw "Required zip entry is missing: $requiredEntry"
      }
    }
  }
  finally {
    $archive.Dispose()
  }
}
finally {
  if (Test-Path -LiteralPath $resolvedWorkDir) {
    Remove-Item -LiteralPath $resolvedWorkDir -Recurse -Force
  }
}

Write-Host 'Created:'
Write-Host "  $resolvedZipFile"
