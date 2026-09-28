# Use the upgraded Flutter SDK (Dart 3.12+ required by pubspec ^3.11.4)
$Flutter = "D:\flutter_windows_3.41.6-stable\flutter\bin\flutter.bat"

if (-not (Test-Path $Flutter)) {
  Write-Error "Flutter not found at $Flutter. Install Flutter 3.44+ or update this path."
  exit 1
}

Set-Location $PSScriptRoot
& $Flutter --version
& $Flutter pub get
if ($args.Count -gt 0) {
  & $Flutter @args
} else {
  & $Flutter run
}
