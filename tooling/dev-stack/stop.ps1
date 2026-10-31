$ErrorActionPreference='Stop'
$distro='PlaySpotAcceptance20261030'
$project='playspot-dev-clean-20261031'
$root=& wsl.exe -d $distro --exec env DOCKER_HOST=unix:///run/playspot-docker.sock docker info --format '{{.DockerRootDir}}'
if($LASTEXITCODE -ne 0 -or $root -ne '/var/lib/playspot-docker'){throw 'Unexpected daemon; no stop attempted'}
$ids=@(& wsl.exe -d $distro --exec env DOCKER_HOST=unix:///run/playspot-docker.sock docker ps --filter "name=$project`$" -q)
foreach($id in $ids){
 $name=& wsl.exe -d $distro --exec env DOCKER_HOST=unix:///run/playspot-docker.sock docker inspect --format '{{.Name}}' $id
 if($LASTEXITCODE -ne 0 -or $name -notlike "/supabase_*_$project"){throw 'Project identity mismatch'}
 & wsl.exe -d $distro --exec env DOCKER_HOST=unix:///run/playspot-docker.sock docker stop $id | Out-Null
 if($LASTEXITCODE -ne 0){throw 'Owned container stop failed'}
}
Write-Output 'Owned containers stopped; volumes, backups, other projects and the fixed loopback relay preserved.'
