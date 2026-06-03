# backup.ps1
# Полный дамп базы certtracker в C:\certtracker\backups\

$ErrorActionPreference = "Stop"
$ROOT = "C:\certtracker"

$config = @{}
Get-Content "$ROOT\config.env" | Where-Object { $_ -match '^\s*([^#=]+)=(.*)$' } | ForEach-Object {
$config[$matches[1].Trim()] = $matches[2].Trim()
}
$pgPort = $config["POSTGRES_PORT"]
$pgPass = $config["POSTGRES_PASSWORD"]

$date = Get-Date -Format "yyyy-MM-dd_HH-mm"
$file = "$ROOT\backups\certtracker-$date.sql"

Write-Host "💾 Создаю бэкап..." -ForegroundColor Yellow
$env:PGPASSWORD = $pgPass
& "$ROOT\pgsql\bin\pg_dump.exe" -h localhost -p $pgPort -U postgres -d certtracker -f $file
Remove-Item Env:\PGPASSWORD

$size = (Get-Item $file).Length / 1KB
Write-Host "  ✅ Сохранён: $file ($([math]::Round($size, 1)) KB)" -ForegroundColor Green

# Удалить бэкапы старше 30 дней
Get-ChildItem "$ROOT\backups\*.sql" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item
Write-Host "  🧹 Старые бэкапы (>30 дней) удалены" -ForegroundColor Gray
