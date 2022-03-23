$ErrorActionPreference = 'Stop';

$installDir = Join-Path (Get-ToolsLocation) "Windterm"
$installSubDir = Join-Path $installDir "WindTerm.portable"

$checksum   = "#REPLACE_CHECKSUM#"
$url        = "#REPLACE_URL#"
$checksum64 = "#REPLACE_CHECKSUM_64#"
$url64      = "#REPLACE_URL_64#"

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  unzipLocation = $installDir
  url           = $url
  checksum      = $checksum
  checksumType  = 'sha256'
  url64bit      = $url64
  checksum64    = $checksum64
  checksumType64= 'sha256'
  validExitCodes= @(0, 3010, 1641)
}

if (Test-Path -Path $installSubDir) { Remove-Item $installSubDir -Recurse }

Install-ChocolateyZipPackage @packageArgs

$extractedFolder = Join-Path $installDir (Get-ChildItem "$installDir" -recurse | Where-Object {$_.PSIsContainer -eq $true -and $_.Name -match "WindTerm_"})
Rename-Item $extractedFolder $installSubDir
$exeFile = Join-Path $installSubDir WindTerm.exe

$bckDir = Join-Path $installDir "bck_profiles"
if(Test-Path -Path $bckDir) {
  $profilesDir = Join-Path $installSubDir "profiles"
  Copy-Item "$bckDir" -Destination "$profilesDir" -Recurse
  Remove-Item "$bckDir" -Recurse
}

$desktopPath = [Environment]::GetFolderPath("Desktop")
Install-ChocolateyShortcut `
  -ShortcutFilePath "$desktopPath\WindTerm.lnk" `
  -TargetPath $exeFile
