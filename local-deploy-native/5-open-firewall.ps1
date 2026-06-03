# 5-open-firewall.ps1
# Открывает порт 80 в брандмауэре Windows, чтобы зайти с других ПК сети

$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
Write-Host "❌ Запусти PowerShell от имени администратора!" -ForegroundColor Red
exit 1
}

$ROOT = "C:\certtracker"
$config = @{}
Get-Content "$ROOT\config.env" | Where-Object { $_ -match '^\s*([^#=]+)=(.*)$' } | ForEach-Object {
$config[$matches[1].Trim()] = $matches[2].Trim()
}
$port = $config["WEB_PORT"]

Write-Host "🔥 Открываю порт $port в брандмауэре..." -ForegroundColor Yellow

# Удалить старое правило если есть
Remove-NetFirewallRule -DisplayName "Cert Tracker Web" -ErrorAction SilentlyContinue

# Создать новое
New-NetFirewallRule -DisplayName "Cert Tracker Web" `
-Direction Inbound `
-LocalPort $port `
-Protocol TCP `
-Action Allow `
-Profile Domain,Private | Out-Null

Write-Host "  ✅ Порт $port открыт для входящих соединений (Private + Domain)" -ForegroundColor Green
Write-Host ""

# Показать IP
Write-Host "Твои IP-адреса в сети:" -ForegroundColor Cyan
Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
$_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.*"
} | ForEach-Object {
Write-Host "  🌐 http://$($_.IPAddress)$(if ($port -ne '80') { ":$port" })" -ForegroundColor White
}
Write-Host ""
Write-Host "Дай эти ссылки коллегам — они откроют сайт из своих браузеров." -ForegroundColor Gray
