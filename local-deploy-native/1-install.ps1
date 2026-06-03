# 1-install.ps1
# Ustanavlivaet PostgreSQL, PostgREST, nginx v C:\certtracker\
# Zapuskat ot admina: .\1-install.ps1

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
$ROOT = "C:\certtracker"

Write-Host "=== Установка Cert Tracker (нативный режим) ===" -ForegroundColor Cyan
Write-Host ""

# Проверка прав
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
Write-Host "[ОШИБКА] Запусти PowerShell от имени администратора!" -ForegroundColor Red
exit 1
}

# Создаём структуру папок
Write-Host "[1] Создаю папки в $ROOT..." -ForegroundColor Yellow
$folders = @("$ROOT", "$ROOT\data", "$ROOT\files", "$ROOT\logs", "$ROOT\web", "$ROOT\backups", "$ROOT\downloads")
foreach ($f in $folders) {
if (-not (Test-Path $f)) { New-Item -ItemType Directory -Path $f -Force | Out-Null }
}
Write-Host "    Готово" -ForegroundColor Green

# === 1. PostgreSQL ===
Write-Host ""
Write-Host "[2/4] Скачиваю PostgreSQL 16..." -ForegroundColor Yellow
$pgZip = "$ROOT\downloads\postgresql.zip"
$pgUrl = "https://get.enterprisedb.com/postgresql/postgresql-16.4-1-windows-x64-binaries.zip"
if (-not (Test-Path "$ROOT\pgsql\bin\postgres.exe")) {
if (-not (Test-Path $pgZip)) {
    Write-Host "    Скачивание (~210 МБ, может занять несколько минут)..."
    Invoke-WebRequest -Uri $pgUrl -OutFile $pgZip -UseBasicParsing
}
Write-Host "    Распаковка..."
Expand-Archive -Path $pgZip -DestinationPath $ROOT -Force
Write-Host "    [OK] PostgreSQL установлен в $ROOT\pgsql" -ForegroundColor Green
} else {
Write-Host "    PostgreSQL уже установлен - пропускаю" -ForegroundColor Gray
}

# === 2. PostgREST ===
Write-Host ""
Write-Host "[3/4] Скачиваю PostgREST..." -ForegroundColor Yellow
$prDir = "$ROOT\postgrest"
$prZip = "$ROOT\downloads\postgrest.zip"
$prUrl = "https://github.com/PostgREST/postgrest/releases/download/v12.2.3/postgrest-v12.2.3-windows-x64.zip"
if (-not (Test-Path "$prDir\postgrest.exe")) {
if (-not (Test-Path $prDir)) { New-Item -ItemType Directory -Path $prDir | Out-Null }
if (-not (Test-Path $prZip)) {
    Write-Host "    Скачивание (~12 МБ)..."
    Invoke-WebRequest -Uri $prUrl -OutFile $prZip -UseBasicParsing
}
Write-Host "    Распаковка..."
Expand-Archive -Path $prZip -DestinationPath $prDir -Force
Write-Host "    [OK] PostgREST установлен в $prDir" -ForegroundColor Green
} else {
Write-Host "    PostgREST уже установлен - пропускаю" -ForegroundColor Gray
}

# === 3. Nginx ===
Write-Host ""
Write-Host "[4/4] Скачиваю Nginx..." -ForegroundColor Yellow
$ngZip = "$ROOT\downloads\nginx.zip"
$ngUrl = "https://nginx.org/download/nginx-1.27.2.zip"
if (-not (Test-Path "$ROOT\nginx\nginx.exe")) {
if (-not (Test-Path $ngZip)) {
    Write-Host "    Скачивание (~5 МБ)..."
    Invoke-WebRequest -Uri $ngUrl -OutFile $ngZip -UseBasicParsing
}
Write-Host "    Распаковка..."
Expand-Archive -Path $ngZip -DestinationPath $ROOT -Force
$ngFolder = Get-ChildItem "$ROOT" -Directory -Filter "nginx-*" | Select-Object -First 1
if ($ngFolder) { Rename-Item -Path $ngFolder.FullName -NewName "nginx" -Force }
Write-Host "    [OK] Nginx установлен в $ROOT\nginx" -ForegroundColor Green
} else {
Write-Host "    Nginx уже установлен - пропускаю" -ForegroundColor Gray
}

# === Создаём config.env ===
Write-Host ""
Write-Host "Создаю config.env..." -ForegroundColor Yellow
$envPath = "$ROOT\config.env"
if (-not (Test-Path $envPath)) {
$pgPass = -join ((48..57) + (97..122) | Get-Random -Count 24 | ForEach-Object {[char]$_})
$jwtSec = -join ((48..57) + (97..122) | Get-Random -Count 48 | ForEach-Object {[char]$_})
$stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
$envContent = @"
# Cert Tracker - nastroyki lokalnogo servera
# Sozdano: $stamp

POSTGRES_PASSWORD=$pgPass
POSTGRES_PORT=5432
POSTGREST_PORT=3000
WEB_PORT=80
JWT_SECRET=$jwtSec
CERT_ROOT=C:\certtracker
"@
Set-Content -Path $envPath -Value $envContent -Encoding UTF8
Write-Host "    [OK] Создан $envPath с автогенерированным паролем" -ForegroundColor Green
Write-Host "    Можешь открыть и поменять пароль на свой" -ForegroundColor Gray
} else {
Write-Host "    config.env уже существует - оставлен как есть" -ForegroundColor Gray
}

# Удаляем загруженные zip
Write-Host ""
Write-Host "Чищу временные файлы..." -ForegroundColor Yellow
Remove-Item "$ROOT\downloads" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "    [OK] Готово" -ForegroundColor Green

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "[OK] Установка завершена!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Следующий шаг - инициализация базы:" -ForegroundColor Cyan
Write-Host "  .\2-init-db.ps1" -ForegroundColor White
