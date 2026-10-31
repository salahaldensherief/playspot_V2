param(
 [Parameter(Mandatory=$true)][string]$DashboardRoot,
 [switch]$Initialize
)
$ErrorActionPreference='Stop'
$mobileRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$distro='PlaySpotAcceptance20261030'
$project='playspot-dev-clean-20261031'
$network='playspot-dev-clean-internal-20261031'
$linuxRoot='/opt/playspot-dev-clean-20261031'
$runtime="\\wsl.localhost\$distro\opt\playspot-dev-clean-20261031"
$registered=@(Get-ItemProperty HKCU:/Software/Microsoft/Windows/CurrentVersion/Lxss/* | Where-Object DistributionName -eq $distro)
if($registered.Count -ne 1 -or $registered[0].BasePath.TrimEnd('\') -ne 'D:\PlaySpotIsolated20261030\wsl'){throw 'Dedicated distro storage identity not verified'}
$dockerRoot=& wsl.exe -d $distro --exec env DOCKER_HOST=unix:///run/playspot-docker.sock docker info --format '{{.DockerRootDir}}'
if($LASTEXITCODE -ne 0 -or $dockerRoot -ne '/var/lib/playspot-docker'){throw 'Start the documented dedicated daemon first; no Docker Desktop fallback'}
foreach($sub in @('project/supabase','private')){if(-not(Test-Path -LiteralPath (Join-Path $runtime $sub))){New-Item -ItemType Directory -Path (Join-Path $runtime $sub) | Out-Null}}
foreach($file in @(@{source='config.toml';target='project/supabase/config.toml'},@{source='loopback_relay.py';target='loopback_relay.py'})){
 $source=Join-Path $PSScriptRoot $file.source;$target=Join-Path $runtime $file.target
 if(Test-Path -LiteralPath $target){
  $expected=([IO.File]::ReadAllText($source)).Replace("`r`n","`n")
  $actual=([IO.File]::ReadAllText($target)).Replace("`r`n","`n")
  if($expected -ne $actual){throw 'Existing runtime configuration differs; preserve and review it, do not overwrite'}
 }else{Copy-Item -LiteralPath $source -Destination $target}
}
& wsl.exe -d $distro --exec chmod 700 "$linuxRoot/private"
$networkInfo=& wsl.exe -d $distro --exec env DOCKER_HOST=unix:///run/playspot-docker.sock docker network inspect $network 2>$null
if($LASTEXITCODE -ne 0){
 & wsl.exe -d $distro --exec env DOCKER_HOST=unix:///run/playspot-docker.sock docker network create --internal --driver bridge -o com.docker.network.bridge.host_binding_ipv4=127.0.0.1 $network | Out-Null
 if($LASTEXITCODE -ne 0){throw 'New internal network creation failed'}
 $networkInfo=& wsl.exe -d $distro --exec env DOCKER_HOST=unix:///run/playspot-docker.sock docker network inspect $network
}
$net=($networkInfo|Out-String|ConvertFrom-Json)[0]
if(-not $net.Internal -or $net.Options.'com.docker.network.bridge.host_binding_ipv4' -ne '127.0.0.1'){throw 'Internal network isolation not verified'}
$sockets=@(& wsl.exe -d $distro --exec ss -H -lntp)
if(-not @($sockets|Where-Object {$_ -match '\s127\.0\.0\.1:56821\s'}).Count){
 $logs='D:\PlaySpotIsolated20261030\launcher-logs';$stamp=[guid]::NewGuid().ToString('N')
 Start-Process wsl.exe -ArgumentList "-d $distro --exec python3 $linuxRoot/loopback_relay.py" -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logs "dev-relay-$stamp.out.log") -RedirectStandardError (Join-Path $logs "dev-relay-$stamp.err.log") | Out-Null
 Start-Sleep -Seconds 1
}
# Fixed reviewed paths only; CLI logs/status containing keys remain private.
& wsl.exe -d $distro --exec sh -c 'umask 077; export DOCKER_HOST=unix:///run/playspot-docker.sock; test "$(/opt/playspot-tools/supabase --version)" = 2.122.0 || exit 1; /opt/playspot-tools/supabase start --workdir /opt/playspot-dev-clean-20261031/project --network-id playspot-dev-clean-internal-20261031 > /opt/playspot-dev-clean-20261031/private/start.log 2>&1 && /opt/playspot-tools/supabase status --workdir /opt/playspot-dev-clean-20261031/project --output json > /opt/playspot-dev-clean-20261031/private/status.json 2>/opt/playspot-dev-clean-20261031/private/status.log'
if($LASTEXITCODE -ne 0){throw 'Owned stack start failed; private diagnostics retained'}
& (Join-Path $PSScriptRoot 'verify.ps1')
if($Initialize){
 & node.exe (Join-Path $PSScriptRoot 'apply-bootstrap.mjs') (Join-Path $runtime 'private') (Join-Path $runtime 'private/bootstrap-report.json')
 if($LASTEXITCODE -ne 0){throw 'Fresh bootstrap failed; preserve evidence, never reset/replay'}
 & node.exe (Join-Path $PSScriptRoot 'seed-synthetic.mjs') (Join-Path $runtime 'private') (Join-Path $runtime 'private/seed-report.json')
 if($LASTEXITCODE -ne 0){throw 'Synthetic setup failed; preserve evidence and fix source'}
}
$status=Get-Content -Raw -LiteralPath (Join-Path $runtime 'private/status.json') | ConvertFrom-Json
if($status.API_URL -ne 'http://127.0.0.1:56821' -or [string]::IsNullOrWhiteSpace($status.ANON_KEY)){throw 'Expected local public settings unavailable'}
foreach($root in @($mobileRoot,(Resolve-Path $DashboardRoot).Path)){
 $file=Join-Path $root '.env.dev-local.json'
 if(Test-Path -LiteralPath $file){
  $existing=Get-Content -Raw -LiteralPath $file | ConvertFrom-Json
  if($existing.SUPABASE_URL -ne $status.API_URL -or $existing.SUPABASE_ANON_KEY -ne $status.ANON_KEY){throw 'Existing client configuration differs; preserve it'}
 }else{
  @{SUPABASE_URL=$status.API_URL;SUPABASE_ANON_KEY=$status.ANON_KEY;PLAYSPOT_LOCAL_ACCEPTANCE=$true}|ConvertTo-Json|Set-Content -Encoding utf8 -LiteralPath $file
 }
}
Write-Output 'Consolidated local backend selected on 127.0.0.1:56821. Private accounts stay in the runtime directory. No app launched.'
