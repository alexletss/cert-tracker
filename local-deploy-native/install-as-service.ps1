# install-as-service.ps1
# Регистрирует автозапуск Cert Tracker при включении Windows через Task Scheduler

$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
Write-Host "❌ Запусти PowerShell от имени администратора!" -ForegroundColor Red
exit 1
}

$startScript = Join-Path $PSScriptRoot "3-start.ps1"
if (-not (Test-Path $startScript)) {
Write-Host "❌ Не найден $startScript" -ForegroundColor Red
exit 1
}

Write-Host "🔧 Регистрирую автозапуск Cert Tracker..." -ForegroundColor Yellow

# Удалить старую задачу, если есть
Unregister-ScheduledTask -TaskName "CertTrackerAutostart" -Confirm:$false -ErrorAction SilentlyContinue

# Создать новую
$action = New-ScheduledTaskAction `
-Execute "powershell.exe" `
-Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$startScript`""

$trigger = New-ScheduledTaskTrigger -AtStartup

$principal = New-ScheduledTaskPrincipal `
-UserId "SYSTEM" `
-LogonType ServiceAccount `
-RunLevel Highest

$settings = New-ScheduledTaskSettingsSet `
-AllowStartIfOnBatteries `
-DontStopIfGoingOnBatteries `
-StartWhenAvailable `
-RestartCount 3 `
-RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask `
-TaskName "CertTrackerAutostart" `
-Description "Запускает Cert Tracker (PostgreSQL + PostgREST + Nginx) при старте Windows" `
-Action $action `
-Trigger $trigger `
-Principal $principal `
-Settings $settings | Out-Null

Write-Host "  ✅ Задача создана: CertTrackerAutostart" -ForegroundColor Green
Write-Host ""
Write-Host "Теперь Cert Tracker будет автоматически запускаться при включении ПК." -ForegroundColor Cyan
Write-Host ""
Write-Host "Проверить:  Get-ScheduledTask -TaskName CertTrackerAutostart" -ForegroundColor Gray
Write-Host "Удалить:    Unregister-ScheduledTask -TaskName CertTrackerAutostart -Confirm:`$false" -ForegroundColor Gray
