# 2-init-db.ps1
# Инициализация PostgreSQL

$ErrorActionPreference = "Stop"
$ROOT = "C:\certtracker"
$PG_BIN = "$ROOT\pgsql\bin"
$PG_DATA = "$ROOT\data"
$LOG = "$ROOT\logs\postgres.log"

Write-Host "=== Инициализация базы данных ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "$PG_BIN\postgres.exe")) {
Write-Host "[ОШИБКА] PostgreSQL не установлен. Сначала запусти .\1-install.ps1" -ForegroundColor Red
exit 1
}

# Читаем config.env
$config = @{}
Get-Content "$ROOT\config.env" -Encoding UTF8 | Where-Object { $_ -match '^\s*([^#=]+)=(.*)$' } | ForEach-Object {
$config[$matches[1].Trim()] = $matches[2].Trim()
}
$pgPass = $config["POSTGRES_PASSWORD"]
$pgPort = $config["POSTGRES_PORT"]
if (-not $pgPass) { Write-Host "[ОШИБКА] POSTGRES_PASSWORD не найден в config.env" -ForegroundColor Red; exit 1 }

# === 1. Инициализация кластера ===
if (-not (Test-Path "$PG_DATA\PG_VERSION")) {
Write-Host "[1] Создаю кластер PostgreSQL в $PG_DATA..." -ForegroundColor Yellow
$pwFile = "$ROOT\.pgpw.tmp"
Set-Content -Path $pwFile -Value $pgPass -NoNewline -Encoding ASCII
& "$PG_BIN\initdb.exe" -D $PG_DATA -U postgres --pwfile=$pwFile -E UTF8 --locale=C 2>&1 | Tee-Object -FilePath $LOG -Append
Remove-Item $pwFile -Force
if ($LASTEXITCODE -ne 0) { Write-Host "[ОШИБКА] initdb - смотри $LOG" -ForegroundColor Red; exit 1 }
Write-Host "    [OK] Кластер создан" -ForegroundColor Green
} else {
Write-Host "[1] Кластер уже инициализирован - пропускаю" -ForegroundColor Gray
}

# Порт в postgresql.conf
$confFile = "$PG_DATA\postgresql.conf"
$confContent = Get-Content $confFile -Raw
if ($confContent -notmatch "(?m)^port\s*=\s*$pgPort\s*$") {
$confContent = $confContent -replace "(?m)^#?port\s*=.*$", "port = $pgPort"
Set-Content -Path $confFile -Value $confContent
}

# Разрешить подключения с localhost
$hbaFile = "$PG_DATA\pg_hba.conf"
if (-not (Select-String -Path $hbaFile -Pattern "host\s+all\s+all\s+127.0.0.1/32\s+md5" -Quiet)) {
Add-Content -Path $hbaFile -Value "host    all             all             127.0.0.1/32            md5"
}

# === 2. Запуск Postgres ===
Write-Host "[2] Запускаю PostgreSQL..." -ForegroundColor Yellow
$existing = Get-Process postgres -ErrorAction SilentlyContinue
if ($existing) {
Write-Host "    Уже запущен (PID $($existing[0].Id))" -ForegroundColor Gray
} else {
Start-Process -FilePath "$PG_BIN\pg_ctl.exe" -ArgumentList "start","-D",$PG_DATA,"-l",$LOG,"-w" -NoNewWindow -Wait
Start-Sleep -Seconds 2
}

# === 3. Создание базы ===
Write-Host "[3] Создаю базу certtracker..." -ForegroundColor Yellow
$env:PGPASSWORD = $pgPass
$dbExists = & "$PG_BIN\psql.exe" -h localhost -p $pgPort -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='certtracker'" 2>$null
if ($dbExists -eq "1") {
Write-Host "    База certtracker уже существует - пропускаю" -ForegroundColor Gray
} else {
& "$PG_BIN\psql.exe" -h localhost -p $pgPort -U postgres -c "CREATE DATABASE certtracker WITH ENCODING 'UTF8' TEMPLATE template0" 2>&1 | Out-Null
Write-Host "    [OK] База создана" -ForegroundColor Green
}

# === 4. Применение схемы ===
Write-Host "[4] Применяю схему из init-db.sql..." -ForegroundColor Yellow
$schemaPath = Join-Path $PSScriptRoot "init-db.sql"
if (-not (Test-Path $schemaPath)) { Write-Host "[ОШИБКА] init-db.sql не найден рядом со скриптом" -ForegroundColor Red; exit 1 }
& "$PG_BIN\psql.exe" -h localhost -p $pgPort -U postgres -d certtracker -f $schemaPath 2>&1 | Out-File "$ROOT\logs\schema.log"
Write-Host "    [OK] Схема применена (см. $ROOT\logs\schema.log)" -ForegroundColor Green

Remove-Item Env:\PGPASSWORD

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "[OK] База данных готова!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Postgres работает на порту $pgPort" -ForegroundColor Cyan
Write-Host "Следующий шаг - запуск всех сервисов:" -ForegroundColor Cyan
Write-Host "  .\3-start.ps1" -ForegroundColor White
