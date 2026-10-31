param(
 [Parameter(Mandatory=$true)][string]$PrivateStatus,
 [Parameter(Mandatory=$true)][string]$DashboardRoot,
 [Parameter(Mandatory=$true)][string]$MobileRoot
)
$ErrorActionPreference='Stop'
$status=Get-Content -LiteralPath $PrivateStatus -Raw|ConvertFrom-Json
if($status.API_URL -ne 'http://127.0.0.1:56621' -or [string]::IsNullOrEmpty($status.ANON_KEY)){throw 'Verified isolated API and public key required'}
# Validate without logging any key. No hosted requests.
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('playspot-public-'+[guid]::NewGuid().ToString('N')+'.json')
try {
 @{SUPABASE_URL=$status.API_URL;SUPABASE_ANON_KEY=$status.ANON_KEY}|ConvertTo-Json|Set-Content -LiteralPath $tmp
 & (Join-Path $DashboardRoot 'scripts/launch_local.ps1') -Environment Local -ConfigFile $tmp -ValidateOnly | Out-Null
 foreach($root in @($DashboardRoot,$MobileRoot)){
   $target=Join-Path $root '.env.isolated.json'
   if(Test-Path $target){
     $prior=Get-Content -LiteralPath $target -Raw|ConvertFrom-Json
     if(-not [string]::IsNullOrEmpty($prior.SUPABASE_URL) -or -not [string]::IsNullOrEmpty($prior.SUPABASE_ANON_KEY)){throw 'Existing nonempty client config preserved; inspect before replacement'}
   }
   & git -C $root check-ignore --quiet .env.isolated.json
   if($LASTEXITCODE -ne 0){throw 'Client config must be gitignored'}
 }
 @{SUPABASE_URL=$status.API_URL;SUPABASE_ANON_KEY=$status.ANON_KEY;PLAYSPOT_LOCAL_ACCEPTANCE=$true}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $DashboardRoot '.env.isolated.json')
 @{SUPABASE_URL=$status.API_URL;SUPABASE_ANON_KEY=$status.ANON_KEY;PLAYSPOT_LOCAL_ACCEPTANCE=$true}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $MobileRoot '.env.isolated.json')
 Write-Output 'Same isolated public configuration written to ignored client files; no application launched.'
} finally {Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue}
