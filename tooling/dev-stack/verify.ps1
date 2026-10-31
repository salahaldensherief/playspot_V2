$ErrorActionPreference='Stop'
$distro='PlaySpotAcceptance20261030';$project='playspot-dev-clean-20261031';$network='playspot-dev-clean-internal-20261031'
$root=& wsl.exe -d $distro --exec env DOCKER_HOST=unix:///run/playspot-docker.sock docker info --format '{{.DockerRootDir}}'
if($LASTEXITCODE -ne 0 -or $root -ne '/var/lib/playspot-docker'){throw 'Wrong daemon storage'}
$ids=@(& wsl.exe -d $distro --exec env DOCKER_HOST=unix:///run/playspot-docker.sock docker ps --filter "name=$project`$" -q)
if($ids.Count -ne 9){throw 'Expected nine owned service containers'}
foreach($id in $ids){
 $raw=& wsl.exe -d $distro --exec env DOCKER_HOST=unix:///run/playspot-docker.sock docker inspect $id
 $container=($raw|Out-String|ConvertFrom-Json)[0]
 if($container.Name -notlike "/supabase_*_$project"){throw 'Unexpected service identity'}
 $networks=@($container.NetworkSettings.Networks.PSObject.Properties.Name)
 if($networks.Count -ne 1 -or $networks[0] -ne $network){throw 'Unexpected network/egress route'}
 foreach($port in $container.NetworkSettings.Ports.PSObject.Properties){foreach($binding in $port.Value){if($binding -and $binding.HostIp -ne '127.0.0.1'){throw 'Non-loopback Docker binding'}}}
}
$sockets=@(& wsl.exe -d $distro --exec ss -H -lntp)
foreach($port in 56821..56824){$bound=@($sockets|Where-Object {$_ -match "\s[^\s]+:${port}\s"});if($bound.Count -ne 1 -or $bound[0] -notmatch "\s127\.0\.0\.1:${port}\s" -or $bound[0] -notmatch 'python3'){throw 'Actual loopback service binding not verified'}}
$listeners=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue|Where-Object {$_.LocalPort -ge 56820 -and $_.LocalPort -le 56829})
if(@($listeners|Where-Object {$_.LocalAddress -notin @('127.0.0.1','::1')}).Count){throw 'Non-loopback Windows listener'}
Write-Output 'New project: nine services, dedicated internal network and actual loopback bindings verified.'
