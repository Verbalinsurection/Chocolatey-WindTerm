$ErrorActionPreference = 'Stop';
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$checksum   = "#REPLACE_CHECKSUM#"
$url        = "#REPLACE_URL#"

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  unzipLocation = $toolsDir
  url           = $url
  checksum      = $checksum
  checksumType  = 'sha256'
  validExitCodes= @(0, 3010, 1641)
}

function GetBuiltinUsersSid {
    $ID = [System.Security.Principal.WellKnownSidType]::BuiltinUsersSid
    $SID = New-Object System.Security.Principal.SecurityIdentifier($ID, $Null)
    return $SID
}

Remove-Item $ENV:ChocolateyInstall\bin\WindTerm*.exe | Out-Null
Remove-Item -Path $toolsDir\WindTerm_* -Recurse -Force | Out-Null

Install-ChocolateyZipPackage @packageArgs

$files = Get-ChildItem $toolsDir -Include *.exe -Recurse
foreach ($file in $files) {
  if (!($file.Name.Equals("WindTerm.exe"))) {
    New-Item "$file.ignore" -type file -Force | Out-Null
  } else {
    New-Item "$file.gui" -type file -Force | Out-Null
  }
}

$installDir = Get-ChildItem "$toolsDir" -recurse | Where-Object {$_.PSIsContainer -eq $true -and $_.Name -match "WindTerm_"}
$profilesDir = "$toolsDir\$installDir\profiles"

New-Item -Path "$profilesDir" -ItemType Directory | out-null

$Acl = Get-ACL $profilesDir
$acl.SetAccessRuleProtection($true, $true)
$acl |Set-Acl
$UsersSid = GetBuiltinUsersSid
$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($UsersSid, "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$Acl.addAccessRule($AccessRule)
$acl |Set-Acl

$bckDir = Get-ChildItem "$toolsDir" -recurse | Where-Object {$_.PSIsContainer -eq $true -and $_.Name -match "bck_profiles"}
if($bckDir) {
  $bckDir = "$toolsDir/$bckDir"
  Copy-Item "$bckDir/*" -Destination "$profilesDir" -Recurse
  Remove-Item "$bckDir" -Recurse
}

$desktopPath = [Environment]::GetFolderPath("Desktop")
Install-ChocolateyShortcut `
  -ShortcutFilePath "$desktopPath\WindTerm.lnk" `
  -TargetPath "$env:ChocolateyInstall\bin\WindTerm.exe"
