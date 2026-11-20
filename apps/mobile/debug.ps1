# Debug run for this Flutter app only. Does not change machine PATH, JAVA_HOME, or any other project.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$flutterBin = Join-Path $env:USERPROFILE 'flutter\bin'
$flutterBat = Join-Path $flutterBin 'flutter.bat'
if (-not (Test-Path $flutterBat)) {
  Write-Error "Flutter not found at $flutterBat"
}
# JDK 17 matches this app's Java 17 settings. Gradle 9.5 is what Flutter 3.50 requires.
# Set only for this script. Android Studio's Java 25 stays in place for other projects.
$jdk = Join-Path $env:USERPROFILE '.jdks\temurin-17'
if (-not (Test-Path (Join-Path $jdk 'bin\java.exe'))) {
  Write-Error "JDK 17 not found at $jdk"
}
$env:JAVA_HOME = $jdk
$env:Path = "$jdk\bin;$flutterBin;" + $env:Path
Set-Location $root

$deviceArgs = @()
$passedDevice = $false
foreach ($arg in $args) {
  if ($arg -eq '-d' -or $arg -eq '--device-id') { $passedDevice = $true }
}
if (-not $passedDevice) {
  $json = & $flutterBat devices --machine | Out-String
  $devices = @()
  if ($json.Trim()) { $devices = $json | ConvertFrom-Json }
  $phone = $devices | Where-Object { $_.targetPlatform -like 'android-*' } | Select-Object -First 1
  if (-not $phone) {
    Write-Host "No Android phone found. Plug it in and allow USB debugging, then run this again."
    & $flutterBat devices
    exit 1
  }
  Write-Host "Debug on $($phone.name) ($($phone.id))"
  $deviceArgs = @('-d', $phone.id)
}

Write-Host "Debug build only. Project: $root"
& $flutterBat run --debug @deviceArgs @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
