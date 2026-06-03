# 3-start.ps1
# Запускает PostgreSQL, PostgREST, nginx в фоне

$ErrorActionPreference = "Continue"
$ROOT = "C:\certtracker"

Write-Host "=== Запуск Cert Tracker ===" -ForegroundColor Cyan
Write-Host ""

$config = @{}
Get-Content "$ROOT\config.env" -Encoding UTF8 | Where-Object { $_ -match '^\s*([^#=]+)=(.*)$' } | ForEach-Object {
$config[$matches[1].Trim()] = $matches[2].Trim()
}
$pgPort = $config["POSTGRES_PORT"]
$prPort = $config["POSTGREST_PORT"]
$webPort = $config["WEB_PORT"]
$pgPass = $config["POSTGRES_PASSWORD"]

# === 1. PostgreSQL ===
Write-Host "[1] PostgreSQL..." -ForegroundColor Yellow -NoNewline
$pg = Get-Process postgres -ErrorAction SilentlyContinue
if ($pg) {
Write-Host " уже запущен (PID $($pg[0].Id))" -ForegroundColor Gray
} else {
Start-Process -FilePath "$ROOT\pgsql\bin\pg_ctl.exe" -ArgumentList "start","-D","$ROOT\data","-l","$ROOT\logs\postgres.log","-w" -NoNewWindow -Wait
Start-Sleep -Seconds 1
Write-Host " [OK] порт $pgPort" -ForegroundColor Green
}

# === 2. postgrest.conf ===
$prConf = "$ROOT\postgrest\postgrest.conf"
$jwt = $config['JWT_SECRET']
$prConfText = @"
db-uri = "postgres://postgres:$pgPass@localhost:$pgPort/certtracker"
db-schemas = "public"
db-anon-role = "anon"
server-host = "0.0.0.0"
server-port = $prPort
jwt-secret = "$jwt"
"@
Set-Content -Path $prConf -Value $prConfText -Encoding ASCII

# === 3. PostgREST ===
Write-Host "[2] PostgREST..." -ForegroundColor Yellow -NoNewline
$pr = Get-Process postgrest -ErrorAction SilentlyContinue
if ($pr) {
Write-Host " уже запущен (PID $($pr[0].Id))" -ForegroundColor Gray
} else {
Start-Process -FilePath "$ROOT\postgrest\postgrest.exe" -ArgumentList "$prConf" -WindowStyle Hidden -RedirectStandardOutput "$ROOT\logs\postgrest.log" -RedirectStandardError "$ROOT\logs\postgrest-err.log"
Start-Sleep -Seconds 2
Write-Host " [OK] порт $prPort" -ForegroundColor Green
}

# === 4. Подготовка nginx.conf ===
$ngConf = "$ROOT
ginx\conf
ginx.conf"
$ngConfTemplate = Join-Path $PSScriptRoot "nginx.conf"
if (Test-Path $ngConfTemplate) {
$template = Get-Content $ngConfTemplate -Raw
$template = $template -replace '__WEB_PORT__', $webPort
$template = $template -replace '__POSTGREST_PORT__', $prPort
$template = $template -replace '__ROOT__', ($ROOT -replace '\\','/')
Set-Content -Path $ngConf -Value $template -Encoding ASCII
}

# === 5. nginx ===
Write-Host "[3] Nginx..." -ForegroundColor Yellow -NoNewline
$ng = Get-Process nginx -ErrorAction SilentlyContinue
if ($ng) {
& "$ROOT
ginx
ginx.exe" -p "$ROOT
ginx\" -s reload
Write-Host " конфиг перезагружен" -ForegroundColor Gray
} else {
Push-Location "$ROOT
ginx"
Start-Process -FilePath ".
ginx.exe" -WindowStyle Hidden
Pop-Location
Start-Sleep -Seconds 1
Write-Host " [OK] порт $webPort" -ForegroundColor Green
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "[OK] Всё запущено!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
$suffix = ""
if ($webPort -ne "80") { $suffix = ":$webPort" }
Write-Host "Сайт:     http://localhost$suffix" -ForegroundColor Cyan
Write-Host "API:      http://localhost$suffix/rest/v1/" -ForegroundColor Cyan
Write-Host "Файлы:    http://localhost$suffix/storage/v1/object/public/" -ForegroundColor Cyan
Write-Host ""
Write-Host "Если сайт ещё не открывается - запусти:" -ForegroundColor Yellow
Write-Host "  .\4-deploy-site.ps1" -ForegroundColor White
