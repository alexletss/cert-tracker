# 1-install.ps1
# Устанавливает PostgreSQL, PostgREST, nginx в C:\certtracker\
# Запускать от админа: .\1-install.ps1

$ErrorActionPreference = "Stop"
$ROOT = "C:\certtracker"

Write-Host "=== Установка Cert Tracker (нативный режим) ===" -ForegroundColor Cyan
Write-Host ""

# Проверка прав
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
Write-Host "❌ Запусти PowerShell от имени администратора!" -ForegroundColor Red
exit 1
}

# Создаём структуру папок
Write-Host "📁 Создаю папки в $ROOT..." -ForegroundColor Yellow
$folders = @("$ROOT", "$ROOT\data", "$ROOT\files", "$ROOT\logs", "$ROOT\web", "$ROOT\backups", "$ROOT\downloads")
foreach ($f in $folders) {
if (-not (Test-Path $f)) { New-Item -ItemType Directory -Path $f -Force | Out-Null }
}
Write-Host "  ✅ Готово" -ForegroundColor Green

# === 1. PostgreSQL ===
Write-Host ""
Write-Host "📦 [1/3] Скачиваю PostgreSQL 16..." -ForegroundColor Yellow
$pgZip = "$ROOT\downloads\postgresql.zip"
$pgUrl = "https://get.enterprisedb.com/postgresql/postgresql-16.4-1-windows-x64-binaries.zip"
if (-not (Test-Path "$ROOT\pgsql\bin\postgres.exe")) {
if (-not (Test-Path $pgZip)) {
    Write-Host "  Скачивание (~210 МБ, может занять несколько минут)..."
    Invoke-WebRequest -Uri $pgUrl -OutFile $pgZip -UseBasicParsing
}
Write-Host "  Распаковка..."
Expand-Archive -Path $pgZip -DestinationPath $ROOT -Force
Write-Host "  ✅ PostgreSQL установлен в $ROOT\pgsql" -ForegroundColor Green
} else {
Write-Host "  ℹ PostgreSQL уже установлен — пропускаю" -ForegroundColor Gray
}

# === 2. PostgREST ===
Write-Host ""
Write-Host "📦 [2/3] Скачиваю PostgREST..." -ForegroundColor Yellow
$prDir = "$ROOT\postgrest"
$prZip = "$ROOT\downloads\postgrest.zip"
$prUrl = "https://github.com/PostgREST/postgrest/releases/download/v12.2.3/postgrest-v12.2.3-windows-x64.zip"
if (-not (Test-Path "$prDir\postgrest.exe")) {
if (-not (Test-Path $prDir)) { New-Item -ItemType Directory -Path $prDir | Out-Null }
if (-not (Test-Path $prZip)) {
    Write-Host "  Скачивание (~12 МБ)..."
    Invoke-WebRequest -Uri $prUrl -OutFile $prZip -UseBasicParsing
}
Write-Host "  Распаковка..."
Expand-Archive -Path $prZip -DestinationPath $prDir -Force
Write-Host "  ✅ PostgREST установлен в $prDir" -ForegroundColor Green
} else {
Write-Host "  ℹ PostgREST уже установлен — пропускаю" -ForegroundColor Gray
}

# === 3. Nginx ===
Write-Host ""
Write-Host "📦 [3/3] Скачиваю Nginx..." -ForegroundColor Yellow
$ngZip = "$ROOT\downloads\nginx.zip"
$ngUrl = "https://nginx.org/download/nginx-1.27.2.zip"
if (-not (Test-Path "$ROOT\nginx\nginx.exe")) {
if (-not (Test-Path $ngZip)) {
    Write-Host "  Скачивание (~5 МБ)..."
    Invoke-WebRequest -Uri $ngUrl -OutFile $ngZip -UseBasicParsing
}
Write-Host "  Распаковка..."
Expand-Archive -Path $ngZip -DestinationPath $ROOT -Force
# Переименовать nginx-1.27.2 -> nginx
$ngFolder = Get-ChildItem "$ROOT" -Directory -Filter "nginx-*" | Select-Object -First 1
if ($ngFolder) { Rename-Item -Path $ngFolder.FullName -NewName "nginx" -Force }
Write-Host "  ✅ Nginx установлен в $ROOT\nginx" -ForegroundColor Green
} else {
Write-Host "  ℹ Nginx уже установлен — пропускаю" -ForegroundColor Gray
}

# === Создаём config.env с дефолтными значениями ===
Write-Host ""
Write-Host "📝 Создаю config.env..." -ForegroundColor Yellow
$envPath = "$ROOT\config.env"
if (-not (Test-Path $envPath)) {
# Сгенерировать случайный пароль и JWT-секрет
$pgPass = -join ((48..57) + (97..122) | Get-Random -Count 24 | % {[char]$_})
$jwtSec = -join ((48..57) + (97..122) | Get-Random -Count 48 | % {[char]$_})
@"
# Cert Tracker — настройки локального сервера
# Сгенерировано автоматически $(Get-Date -Format "yyyy-MM-dd HH:mm")

# Пароль для PostgreSQL (поменяй если хочешь свой)
POSTGRES_PASSWORD=$pgPass

# Порт для Postgres (обычно 5432, поменяй если занят)
POSTGRES_PORT=5432

# Порт для PostgREST API (через него ходит сайт)
POSTGREST_PORT=3000

# Порт для веб-сервера (сайт)
WEB_PORT=80

# JWT-секрет (для подписи токенов)
JWT_SECRET=$jwtSec

# Путь к корню (не меняй)
CERT_ROOT=C:\certtracker
"@ | Set-Content -Path $envPath -Encoding UTF8
Write-Host "  ✅ Создан $envPath с автогенерированным паролем" -ForegroundColor Green
Write-Host "  ℹ Можешь открыть и поменять пароль на свой" -ForegroundColor Gray
} else {
Write-Host "  ℹ config.env уже существует — оставлен как есть" -ForegroundColor Gray
}

# Удаляем загруженные zip
Write-Host ""
Write-Host "🧹 Чищу временные файлы..." -ForegroundColor Yellow
Remove-Item "$ROOT\downloads" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  ✅ Готово" -ForegroundColor Green

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "✅ Установка завершена!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Следующий шаг — инициализация базы:" -ForegroundColor Cyan
Write-Host "  .\2-init-db.ps1" -ForegroundColor White
