# Deploys the backend to the Oracle VM in one command.
#
# First time:  .\push_to_server.ps1 -Ip <PUBLIC_IP> -KeyPath <path\to\ssh\key>
# Every later: .\push_to_server.ps1 -Ip <PUBLIC_IP> -KeyPath <key> (same)
#
# Requires: Windows 10+ (built-in tar + ssh/scp), the VM bootstrapped with
# server_setup.sh, and port 80 open in the instance's Security List.
param(
    [Parameter(Mandatory = $true)][string]$Ip,
    [Parameter(Mandatory = $true)][string]$KeyPath,
    [string]$User = "ubuntu"
)

$ErrorActionPreference = "Stop"
$remoteRoot = "/opt/ibajay-eats"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path  # backend/deploy
$backend = Split-Path -Parent $here                     # backend/

Write-Host "== Packing backend (excluding venv/caches/.env) =="
$tar = Join-Path $env:TEMP "ibajay-backend.tar.gz"
if (Test-Path $tar) { Remove-Item $tar }
tar -czf $tar -C $backend --exclude=venv --exclude=.venv --exclude=__pycache__ --exclude=.env --exclude=deploy .

Write-Host "== Uploading code + .env to $User@$Ip =="
scp -i $KeyPath -o StrictHostKeyChecking=accept-new $tar "${User}@${Ip}:/tmp/ibajay-backend.tar.gz"
scp -i $KeyPath (Join-Path $backend ".env") "${User}@${Ip}:/tmp/ibajay-eats.env"

Write-Host "== Building + restarting container on the server =="
$remote = @"
set -e
mkdir -p $remoteRoot/backend
tar -xzf /tmp/ibajay-backend.tar.gz -C $remoteRoot/backend
cp /tmp/ibajay-eats.env $remoteRoot/backend/.env
cd $remoteRoot/backend
docker build -t ibajay-eats-api .
docker rm -f ibajay-eats-api 2>/dev/null || true
docker run -d --name ibajay-eats-api --restart unless-stopped -p 80:8000 --env-file .env ibajay-eats-api
rm /tmp/ibajay-backend.tar.gz /tmp/ibajay-eats.env
docker ps --filter name=ibajay-eats-api --format 'running: {{.Status}}'
"@
$remote | ssh -i $KeyPath "${User}@${Ip}" "bash -s"

Write-Host "== Verifying http://$Ip/health =="
Start-Sleep -Seconds 3
try {
    (Invoke-WebRequest -Uri "http://$Ip/health" -UseBasicParsing -TimeoutSec 15).Content
    Write-Host "Deploy OK - API is live at http://$Ip" -ForegroundColor Green
} catch {
    Write-Host "Container is up but /health unreachable - check the Security List ingress rule for port 80." -ForegroundColor Yellow
}
