param(
    [Parameter(Mandatory)]
    [string] $ApkPath,

    [Parameter(Mandatory)]
    [string] $BuildToolsPath
)

$ErrorActionPreference = 'Stop'
$signedApk = (Resolve-Path -LiteralPath $ApkPath).Path
$buildTools = (Resolve-Path -LiteralPath $BuildToolsPath).Path
& (Join-Path $buildTools 'apksigner.bat') verify $signedApk
if ($LASTEXITCODE -ne 0) {
    throw 'The APK signature could not be verified.'
}

$badging = & (Join-Path $buildTools 'aapt.exe') dump badging $signedApk
if ($LASTEXITCODE -ne 0) {
    throw 'The APK metadata could not be read.'
}

$packageLine = $badging | Where-Object { $_.StartsWith('package:') } | Select-Object -First 1
if ($packageLine -notmatch "^package: name='com\.silverlight\.dndadventurers' versionCode='([1-9][0-9]*)'") {
    throw 'Expected a DnD Adventurers APK with a positive version code.'
}
$versionCode = [int] $Matches[1]

$outputDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) 'release-assets'
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$releaseApk = Join-Path $outputDirectory 'dnd-adventurers.apk'
if ($signedApk -ne $releaseApk) {
    Copy-Item -LiteralPath $signedApk -Destination $releaseApk -Force
}
$sha256 = (Get-FileHash -LiteralPath $releaseApk -Algorithm SHA256).Hash.ToLowerInvariant()
$metadata = @{ versionCode = $versionCode; sha256 = $sha256 } | ConvertTo-Json -Compress
[System.IO.File]::WriteAllText((Join-Path $outputDirectory 'update.json'), $metadata)
Write-Output "Release assets for version code $versionCode are in $outputDirectory."
