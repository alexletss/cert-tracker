# 4-stop.ps1
# Останавливает PostgreSQL, PostgREST, nginx

$ROOT = "C:\certtracker"

Write-Host "=== Остановка Cert Tracker ===" -ForegroundColor Cyan
Write-Host ""

# Nginx (graceful)
Write-Host "🛑 Nginx..." -ForegroundColor Yellow -NoNewline
if (Get-Process nginx -ErrorAction SilentlyContinue) {
& "$ROOT
ginx
ginx.exe" -p "$ROOT
ginx\" -s quit 2>$null
Start-Sleep -Seconds 1
Get-Process nginx -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host " остановлен" -ForegroundColor Green
} else {
Write-Host " не запущен" -ForegroundColor Gray
}

# PostgREST
Write-Host "🛑 PostgREST..." -ForegroundColor Yellow -NoNewline
$pr = Get-Process postgrest -ErrorAction SilentlyContinue
if ($pr) {
$pr | Stop-Process -Force
Write-Host " остановлен" -ForegroundColor Green
} else {
Write-Host " не запущен" -ForegroundColor Gray
}

# PostgreSQL (graceful)
Write-Host "🛑 PostgreSQL..." -ForegroundColor Yellow -NoNewline
if (Get-Process postgres -ErrorAction SilentlyContinue) {
& "$ROOT\pgsql\bin\pg_ctl.exe" stop -D "$ROOT\data" -m fast 2>$null
Start-Sleep -Seconds 2
Write-Host " остановлен" -ForegroundColor Green
} else {
Write-Host " не запущен" -ForegroundColor Gray
}

Write-Host ""
Write-Host "✅ Всё остановлено" -ForegroundColor Green
