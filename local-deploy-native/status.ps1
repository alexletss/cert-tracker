# status.ps1
# Показывает статус всех сервисов

$ROOT = "C:\certtracker"

$config = @{}
if (Test-Path "$ROOT\config.env") {
Get-Content "$ROOT\config.env" -Encoding UTF8 | Where-Object { $_ -match '^\s*([^#=]+)=(.*)$' } | ForEach-Object {
    $config[$matches[1].Trim()] = $matches[2].Trim()
}
}

Write-Host "=== Статус Cert Tracker ===" -ForegroundColor Cyan
Write-Host ""

function Show-Status($name, $process, $port) {
$p = Get-Process $process -ErrorAction SilentlyContinue
if ($p) {
    $pid_str = ($p | Select-Object -First 1).Id
    Write-Host ("  {0,-12} " -f $name) -NoNewline
    Write-Host "[OK] работает  " -ForegroundColor Green -NoNewline
    Write-Host ("PID $pid_str, порт $port") -ForegroundColor Gray
} else {
    Write-Host ("  {0,-12} " -f $name) -NoNewline
    Write-Host "[X] остановлен" -ForegroundColor Red
}
}

Show-Status "PostgreSQL" "postgres" $config["POSTGRES_PORT"]
Show-Status "PostgREST"  "postgrest" $config["POSTGREST_PORT"]
Show-Status "Nginx"      "nginx" $config["WEB_PORT"]

Write-Host ""
$webPort = $config["WEB_PORT"]
$suffix = ""
if ($webPort -ne "80") { $suffix = ":$webPort" }
$url = "http://localhost$suffix"
Write-Host "Адрес: $url" -ForegroundColor Cyan

try {
$r = Invoke-WebRequest -Uri "$url/rest/v1/" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
Write-Host "API:   отвечает (HTTP $($r.StatusCode))" -ForegroundColor Green
} catch {
Write-Host "API:   не отвечает" -ForegroundColor Red
}
