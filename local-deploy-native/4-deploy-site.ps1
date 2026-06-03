# 4-deploy-site.ps1
# Копирует index.html в C:\certtracker\web\ и подменяет URL Supabase

$ErrorActionPreference = "Stop"
$ROOT = "C:\certtracker"

Write-Host "=== Деплой сайта ===" -ForegroundColor Cyan
Write-Host ""

# Найти исходный index.html — он лежит на 2 уровня выше скрипта (в корне репо)
$source = Join-Path (Split-Path $PSScriptRoot -Parent) "index.html"
if (-not (Test-Path $source)) {
Write-Host "[ОШИБКА] Не найден $source" -ForegroundColor Red
Write-Host "    Убедись что скрипт лежит внутри клонированного репозитория cert-tracker" -ForegroundColor Gray
exit 1
}

Write-Host "[1] Копирую $source..." -ForegroundColor Yellow
$content = Get-Content $source -Raw -Encoding UTF8

Write-Host "[2] Подменяю URL Supabase на локальные..." -ForegroundColor Yellow
$content = $content -replace 'const SUPABASE_URL = "https://fpvusjatdwqzedhgljru\.supabase\.co";', 'const SUPABASE_URL = "http://" + location.hostname + (location.port ? ":" + location.port : "");'
$content = $content -replace 'const SUPABASE_KEY = "sb_publishable_GnvmwL6B_MPvDdiqDRljmA_VrfsX7da";', 'const SUPABASE_KEY = "local-dev-key";'

$target = "$ROOT\web\index.html"
Set-Content -Path $target -Value $content -Encoding UTF8 -NoNewline
Write-Host "    [OK] Скопировано в $target" -ForegroundColor Green

# Перезагрузить nginx
Write-Host "[3] Перезагружаю nginx..." -ForegroundColor Yellow
$ng = Get-Process nginx -ErrorAction SilentlyContinue
if ($ng) {
& "$ROOT\nginx\nginx.exe" -p "$ROOT\nginx\" -s reload
Write-Host "    [OK] Готово" -ForegroundColor Green
} else {
Write-Host "    [!] Nginx не запущен - запусти .\3-start.ps1" -ForegroundColor Yellow
}

# Прочитать порт
$config = @{}
Get-Content "$ROOT\config.env" -Encoding UTF8 | Where-Object { $_ -match '^\s*([^#=]+)=(.*)$' } | ForEach-Object {
$config[$matches[1].Trim()] = $matches[2].Trim()
}
$webPort = $config["WEB_PORT"]
$suffix = ""
if ($webPort -ne "80") { $suffix = ":$webPort" }

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "[OK] Сайт развёрнут!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Открой: http://localhost$suffix" -ForegroundColor Cyan
Write-Host "Логин: admin / cert2026" -ForegroundColor Cyan
