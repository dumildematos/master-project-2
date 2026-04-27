# build_apk.ps1 — builds the release APK with two protections:
#   1. Pauses OneDrive to prevent file-locking errors on native libs
#   2. Sets PUB_CACHE to C:\PubCache (outside AppData) so the pub cache
#      is never corrupted by incomplete downloads or OneDrive interference

$env:PUB_CACHE = "C:\PubCache"
New-Item -ItemType Directory -Force "C:\PubCache" | Out-Null

$oneDrivePath  = "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
$oneDriveRunning = Get-Process OneDrive -ErrorAction SilentlyContinue

if ($oneDriveRunning) {
    Write-Host "Pausing OneDrive sync..."
    Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

try {
    flutter pub get
    flutter build apk $args
} finally {
    if ($oneDriveRunning -and (Test-Path $oneDrivePath)) {
        Write-Host "Restarting OneDrive..."
        Start-Process $oneDrivePath
    }
}
