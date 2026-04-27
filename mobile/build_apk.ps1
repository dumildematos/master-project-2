# build_apk.ps1 — builds the release APK after pausing OneDrive to prevent
# file-locking errors on native libs inside the OneDrive-synced project folder.

$oneDrivePath = "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
$oneDriveRunning = Get-Process OneDrive -ErrorAction SilentlyContinue

if ($oneDriveRunning) {
    Write-Host "Pausing OneDrive sync..."
    Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

try {
    flutter build apk $args
} finally {
    if ($oneDriveRunning -and (Test-Path $oneDrivePath)) {
        Write-Host "Restarting OneDrive..."
        Start-Process $oneDrivePath
    }
}
