param([Parameter(Mandatory=$true)][string]$DashboardRoot)
$ErrorActionPreference='Stop'
$mobileRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$distro='PlaySpotAcceptance20261030'
$registered=@(Get-ItemProperty HKCU:/Software/Microsoft/Windows/CurrentVersion/Lxss/* | Where-Object DistributionName -eq $distro)
if($registered.Count -ne 1 -or $registered[0].BasePath.TrimEnd('\') -ne 'D:\PlaySpotIsolated20261030\wsl'){throw 'Dedicated storage identity not verified'}
$logs='D:\PlaySpotIsolated20261030\launcher-logs'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
function Start-OwnedProcess($file,$arguments,$label){
  $stamp=[guid]::NewGuid().ToString('N')
  Start-Process -FilePath $file -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logs "$label-$stamp.out.log") -RedirectStandardError (Join-Path $logs "$label-$stamp.err.log") | Out-Null
}
function Test-LocalPort([int]$port){
  $client=[Net.Sockets.TcpClient]::new()
  try { $task=$client.ConnectAsync('127.0.0.1',$port);return ($task.Wait(300) -and $client.Connected) } catch {return $false} finally {$client.Dispose()}
}
$root=& wsl.exe -d $distro --exec env DOCKER_HOST=unix:///run/playspot-docker.sock docker info --format '{{.DockerRootDir}}' 2>$null
if($LASTEXITCODE -ne 0){
  Start-OwnedProcess 'wsl.exe' '-d PlaySpotAcceptance20261030 --exec sh /opt/playspot-acceptance/daemon.sh' 'daemon'
  for($attempt=0;$attempt -lt 30;$attempt++){
    Start-Sleep -Seconds 1
    $root=& wsl.exe -d $distro --exec env DOCKER_HOST=unix:///run/playspot-docker.sock docker info --format '{{.DockerRootDir}}' 2>$null
    if($LASTEXITCODE -eq 0){break}
  }
}
if($root -ne '/var/lib/playspot-docker'){throw 'Dedicated daemon unavailable; no Docker Desktop fallback'}
if(-not(Test-LocalPort 56621)){
  Start-OwnedProcess 'wsl.exe' '-d PlaySpotAcceptance20261030 --exec python3 /opt/playspot-acceptance/loopback_relay.py' 'relay'
  Start-Sleep -Seconds 2
}
$running=@(& wsl.exe -d $distro --exec env DOCKER_HOST=unix:///run/playspot-docker.sock docker ps --format '{{.Names}}')
if(@($running|Where-Object {$_ -like 'supabase_*_playspot-acceptance-20261030'}).Count -ne 9){
  & (Join-Path $PSScriptRoot 'stack.ps1') start
}
& (Join-Path $PSScriptRoot 'stack.ps1') verify
$server=Join-Path $PSScriptRoot 'local-web-server.mjs'
$node=(Get-Command node.exe -ErrorAction Stop).Source
foreach($app in @(@{root=$DashboardRoot;mode='dashboard';port=51651},@{root=$mobileRoot;mode='mobile';port=51652})){
  if(-not(Test-Path (Join-Path $app.root 'build/web/index.html'))){throw 'Prepared main application build missing; do not serve a fixture instead'}
  if(-not(Test-LocalPort $app.port)){
    $arguments='"'+$server+'" "'+(Join-Path $app.root 'build/web')+'" '+$app.mode
    Start-OwnedProcess $node $arguments $app.mode
  }
}
Write-Output 'Local stack verified. Dashboard: http://127.0.0.1:51651/login. Android requires adb reverse tcp:56621 tcp:56621.'
