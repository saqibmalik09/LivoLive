# List devices visible to this Flutter SDK. Process-local PATH only.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$flutterBin = Join-Path $env:USERPROFILE 'flutter\bin'
$flutterBat = Join-Path $flutterBin 'flutter.bat'
if (-not (Test-Path $flutterBat)) {
  Write-Error "Flutter not found at $flutterBat"
}
$env:Path = "$flutterBin;" + $env:Path
Set-Location $root
& $flutterBat devices @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
