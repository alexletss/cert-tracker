# 3-start.ps1
# Запускает PostgreSQL, PostgREST, nginx в фоне

$ErrorActionPreference = "Continue"
$ROOT = "C:\certtracker"

Write-Host "=== Запуск Cert Tracker ===" -ForegroundColor Cyan
Write-Host ""

# Читаем config
$config = @{}
Get-Content "$ROOT\config.env" | Where-Object { $_ -match '^\s*([^#=]+)=(.*)$' } | ForEach-Object {
$config[$matches[1].Trim()] = $matches[2].Trim()
}
$pgPort = $config["POSTGRES_PORT"]
$prPort = $config["POSTGREST_PORT"]
$webPort = $config["WEB_PORT"]
$pgPass = $config["POSTGRES_PASSWORD"]

# === 1. PostgreSQL ===
Write-Host "▶️ PostgreSQL..." -ForegroundColor Yellow -NoNewline
$pg = Get-Process postgres -ErrorAction SilentlyContinue
if ($pg) {
Write-Host " уже запущен (PID $($pg[0].Id))" -ForegroundColor Gray
} else {
Start-Process -FilePath "$ROOT\pgsql\bin\pg_ctl.exe" -ArgumentList "start","-D","$ROOT\data","-l","$ROOT\logs\postgres.log","-w" -NoNewWindow -Wait
Start-Sleep -Seconds 1
Write-Host " ✅ порт $pgPort" -ForegroundColor Green
}

# === 2. Создать postgrest.conf если ещё нет ===
$prConf = "$ROOT\postgrest\postgrest.conf"
if (-not (Test-Path $prConf)) {
@"
db-uri = "postgres://postgres:$pgPass@localhost:$pgPort/certtracker"
db-schemas = "public"
db-anon-role = "anon"
server-host = "0.0.0.0"
server-port = $prPort
jwt-secret = "$($config['JWT_SECRET'])"
"@ | Set-Content -Path $prConf -Encoding UTF8
}

# === 3. PostgREST ===
Write-Host "▶️ PostgREST..." -ForegroundColor Yellow -NoNewline
$pr = Get-Process postgrest -ErrorAction SilentlyContinue
if ($pr) {
Write-Host " уже запущен (PID $($pr[0].Id))" -ForegroundColor Gray
} else {
Start-Process -FilePath "$ROOT\postgrest\postgrest.exe" -ArgumentList "$prConf" -WindowStyle Hidden -RedirectStandardOutput "$ROOT\logs\postgrest.log" -RedirectStandardError "$ROOT\logs\postgrest-err.log"
Start-Sleep -Seconds 2
Write-Host " ✅ порт $prPort" -ForegroundColor Green
}

# === 4. Подготовка nginx.conf ===
$ngConf = "$ROOT\nginx\conf\nginx.conf"
$ngConfTemplate = Join-Path $PSScriptRoot "nginx.conf"
if (Test-Path $ngConfTemplate) {
$template = Get-Content $ngConfTemplate -Raw
$template = $template -replace '__WEB_PORT__', $webPort
$template = $template -replace '__POSTGREST_PORT__', $prPort
$template = $template -replace '__ROOT__', ($ROOT -replace '\\','/')
Set-Content -Path $ngConf -Value $template -Encoding UTF8
}

# === 5. nginx ===
Write-Host "▶️ Nginx..." -ForegroundColor Yellow -NoNewline
$ng = Get-Process nginx -ErrorAction SilentlyContinue
if ($ng) {
# Перезагрузка конфига
& "$ROOT\nginx\nginx.exe" -p "$ROOT\nginx\" -s reload
Write-Host " конфиг перезагружен" -ForegroundColor Gray
} else {
Push-Location "$ROOT\nginx"
Start-Process -FilePath ".\nginx.exe" -WindowStyle Hidden
Pop-Location
Start-Sleep -Seconds 1
Write-Host " ✅ порт $webPort" -ForegroundColor Green
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "✅ Всё запущено!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 Сайт:     http://localhost:$webPort" -ForegroundColor Cyan
Write-Host "🔌 API:      http://localhost:$webPort/rest/v1/" -ForegroundColor Cyan
Write-Host "📁 Файлы:    http://localhost:$webPort/files/" -ForegroundColor Cyan
Write-Host ""
Write-Host "Если сайт ещё не открывается — запусти:" -ForegroundColor Yellow
Write-Host "  .\4-deploy-site.ps1" -ForegroundColor White
