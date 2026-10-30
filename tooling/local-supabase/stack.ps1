param([ValidateSet('start','stop','verify')][string]$Action='verify')
$ErrorActionPreference='Stop'
$distro='PlaySpotAcceptance20261030'
$expected='D:\PlaySpotIsolated20261030\wsl'
$registeredDistro=@(Get-ChildItem HKCU:/Software/Microsoft/Windows/CurrentVersion/Lxss | ForEach-Object {Get-ItemProperty $_.PSPath} | Where-Object {$_.DistributionName -eq $distro})
if($registeredDistro.Count -ne 1 -or $registeredDistro[0].BasePath.TrimEnd('\') -ne $expected){throw 'Dedicated WSL storage identity is not verified'}
& wsl.exe -d $distro --exec /bin/sh /opt/playspot-acceptance/stack.sh $Action
if($LASTEXITCODE -ne 0){throw 'Isolated stack operation failed; do not fall back to Docker Desktop'}
if ($Action -ne 'stop') {
  $ids=@(& wsl.exe -d $distro --exec env DOCKER_HOST=unix:///run/playspot-docker.sock docker ps -q)
  if($LASTEXITCODE -ne 0 -or $ids.Count -eq 0){throw 'No verified running local services'}
  foreach($id in $ids){
    $raw=& wsl.exe -d $distro --exec env DOCKER_HOST=unix:///run/playspot-docker.sock docker inspect $id
    if($LASTEXITCODE -ne 0){throw 'Cannot inspect service isolation'}
    $container=($raw | Out-String | ConvertFrom-Json)[0]
    if($container.Name -notlike '/supabase_*_playspot-acceptance-20261030'){throw 'Unexpected container in isolated daemon'}
    $networks=@($container.NetworkSettings.Networks.PSObject.Properties.Name)
    if($networks.Count -ne 1 -or $networks[0] -ne 'playspot-acceptance-internal'){throw 'Unexpected service network; do not connect clients'}
    foreach($port in $container.NetworkSettings.Ports.PSObject.Properties){
      foreach($binding in $port.Value){if($binding -and $binding.HostIp -ne '127.0.0.1'){throw 'Non-loopback actual Docker binding; stop this isolated stack'}}
    }
  }
  # Docker 29 ignores published ports on an internal bridge. Verify the actual
  # dedicated guest relay listeners instead of trusting requested PortBindings.
  $sockets=@(& wsl.exe -d $distro --exec ss -H -lntp)
  foreach($port in 56621..56624){
    $bound=@($sockets | Where-Object {$_ -match "\s[^\s]+:${port}\s"})
    if($bound.Count -ne 1 -or $bound[0] -notmatch "\s127\.0\.0\.1:${port}\s" -or $bound[0] -notmatch 'python3'){throw 'Dedicated guest loopback listener not verified'}
  }
  $listeners=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object {$_.LocalPort -ge 56620 -and $_.LocalPort -le 56629})
  if(@($listeners | Where-Object {$_.LocalAddress -notin @('127.0.0.1','::1')}).Count){throw 'Non-loopback Windows forward; stop isolated services, do not alter host firewall'}
  Write-Output 'Service network and actual published bindings passed loopback checks.'
}
