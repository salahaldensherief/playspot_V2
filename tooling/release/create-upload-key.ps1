param(
  [Parameter(Mandatory=$true)][string]$SecretsDirectory,
  [Parameter(Mandatory=$true)][string]$BackupDirectory
)
$ErrorActionPreference='Stop'
$mobileRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$properties=Join-Path $mobileRoot 'android/key.properties'
$keytool=(Get-Command keytool.exe -ErrorAction Stop).Source
foreach($path in @($SecretsDirectory,$BackupDirectory,$properties)){
  if(Test-Path -LiteralPath $path){throw 'Signing destination already exists; preserve it and inspect before proceeding.'}
}
foreach($path in @($SecretsDirectory,$BackupDirectory)){
  $absolute=[IO.Path]::GetFullPath($path)
  if($absolute.StartsWith($mobileRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Signing storage must be outside the repository'}
}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent().User
function Protect-Path([string]$path,[bool]$directory){
  $acl=Get-Acl -LiteralPath $path
  $acl.SetAccessRuleProtection($true,$false)
  $inherit=if($directory){[Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit'}else{[Security.AccessControl.InheritanceFlags]::None}
  foreach($sid in @($identity,[Security.Principal.SecurityIdentifier]::new('S-1-5-18'))){
    $rule=[Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl',$inherit,'None','Allow')
    $acl.AddAccessRule($rule)
  }
  Set-Acl -LiteralPath $path -AclObject $acl
}
foreach($path in @($SecretsDirectory,$BackupDirectory)){
  New-Item -ItemType Directory -Path $path | Out-Null
  Protect-Path $path $true
}
$storePass=[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
$keyPass=[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
try {
  $env:PLAYSPOT_UPLOAD_STORE_PASSWORD=$storePass
  $env:PLAYSPOT_UPLOAD_KEY_PASSWORD=$keyPass
  $keystore=Join-Path $SecretsDirectory 'playspot-upload.jks'
  & $keytool -genkeypair -keystore $keystore -storetype JKS -alias upload -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=PlaySpot Upload, O=PlaySpot, C=EG' -storepass:env PLAYSPOT_UPLOAD_STORE_PASSWORD -keypass:env PLAYSPOT_UPLOAD_KEY_PASSWORD
  if($LASTEXITCODE -ne 0){throw 'Key generation failed; preserve all generated files for inspection'}
  foreach($item in @(@{name='store-password.dpapi';value=$storePass},@{name='key-password.dpapi';value=$keyPass})){
    ConvertTo-SecureString $item.value -AsPlainText -Force | ConvertFrom-SecureString | Set-Content -LiteralPath (Join-Path $SecretsDirectory $item.name) -Encoding utf8
  }
  & $keytool -exportcert -rfc -alias upload -keystore $keystore -storepass:env PLAYSPOT_UPLOAD_STORE_PASSWORD -file (Join-Path $SecretsDirectory 'upload-certificate.pem')
  if($LASTEXITCODE -ne 0){throw 'Public certificate export failed'}
  $keyPath=$keystore.Replace('\','/')
  [IO.File]::WriteAllText($properties,"storeFile=$keyPath`nstorePassword=$storePass`nkeyAlias=upload`nkeyPassword=$keyPass`n")
  Protect-Path $properties $false
  foreach($name in @('playspot-upload.jks','store-password.dpapi','key-password.dpapi','upload-certificate.pem')){
    Copy-Item -LiteralPath (Join-Path $SecretsDirectory $name) -Destination (Join-Path $BackupDirectory $name)
    if((Get-FileHash -LiteralPath (Join-Path $SecretsDirectory $name)).Hash -ne (Get-FileHash -LiteralPath (Join-Path $BackupDirectory $name)).Hash){throw 'Signing backup checksum mismatch'}
  }
  $backupPassword=(Get-Content -Raw -LiteralPath (Join-Path $BackupDirectory 'store-password.dpapi')).Trim() | ConvertTo-SecureString
  $env:PLAYSPOT_UPLOAD_STORE_PASSWORD=[Net.NetworkCredential]::new('',$backupPassword).Password
  & $keytool -list -alias upload -keystore (Join-Path $BackupDirectory 'playspot-upload.jks') -storepass:env PLAYSPOT_UPLOAD_STORE_PASSWORD
  if($LASTEXITCODE -ne 0){throw 'Backup keystore reopening failed'}
  @'
PlaySpot UPLOAD key; not a Google Play App Signing enrollment.
Passwords are DPAPI encrypted for the creating Windows account and this machine.
Both this folder and its backup grant only that account and SYSTEM access.
Restore the keystore by copying it to a protected path. Decrypt password files
locally with ConvertTo-SecureString and reconstruct ignored android/key.properties.
Never print those values or put these files in Git/chat/logs.
This same-disk backup is not off-device disaster recovery: securely export a copy
and credentials to an owner-managed vault before the first store submission.
No Google Play upload/publication has been performed.
'@ | Set-Content -LiteralPath (Join-Path $SecretsDirectory 'RECOVERY.txt') -Encoding utf8
  Copy-Item -LiteralPath (Join-Path $SecretsDirectory 'RECOVERY.txt') -Destination (Join-Path $BackupDirectory 'RECOVERY.txt')
  Write-Output 'Dedicated upload key created; protected backup hashes and reopening verified. No passwords printed.'
} finally {
  Remove-Item Env:PLAYSPOT_UPLOAD_STORE_PASSWORD -ErrorAction SilentlyContinue
  Remove-Item Env:PLAYSPOT_UPLOAD_KEY_PASSWORD -ErrorAction SilentlyContinue
  $storePass=$null;$keyPass=$null
}
