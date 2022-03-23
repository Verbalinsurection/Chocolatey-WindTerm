param (
	[Alias('f')]
    [switch]$force = $false,
  [Alias('d')]
    [switch]$debug = $false,
  [Alias('np')]
    [switch]$noPrompt = $false,
  [Alias('v')]
    [string]$fversion = [string]::Empty
)
if ($Debug) { $DebugPreference = 'Continue' }

function getNormVerion {
  param (
    [string]$version
  )
  if ($version.length -lt 3) {
    $nver = [Version]::new($version, 0, 0, 0)
  } else {
    $nver = [Version] $version
    if($nver.Minor -eq -1) {$nver = [Version]::new($nver.Major, 0, 0, 0)}
    if($nver.Build -eq -1) {$nver = [Version]::new($nver.Major, $nver.Minor, 0, 0)}
    if($nver.Revision -eq -1) {$nver = [Version]::new($nver.Major, $nver.Minor, $nver.Build, 0)}
  }
  return "$($nver.Major).$($nver.Minor).$($nver.Build).$($nver.Revision)"
}

function ReplaceInFile {
  param (
    [string]$FilePath,
    [string[]]$SrcText,
    [string[]]$TargetText
  )

  $utf8 = New-Object System.Text.UTF8Encoding $false
  $RawData = Get-Content $FilePath -Raw
  for ($index = 0; $index -lt $SrcText.count; $index++) {
      $RawData = $RawData.replace($SrcText[$index], $TargetText[$index])
  }
  Set-Content -Value $utf8.GetBytes($RawData) -Encoding Byte -Path $FilePath
}

function GetGithubInfos {
  param (
    [string]$repo
  )

  if ($fversion -eq [string]::Empty) {
    Write-Debug "Get Github infos: https://api.github.com/repos/$repo/releases?per_page=5"
    $releasePage = (Invoke-WebRequest "https://api.github.com/repos/$repo/releases?per_page=5" | ConvertFrom-Json)
    $releaseFiltered = ($releasePage | Select-Object tag_name, prerelease, html_url, assets | Where-Object {$_.prerelease -match "False"})[0]
  } else {
    Write-Debug "Get Github infos: https://api.github.com/repos/$repo/releases for version $fversion"
    $releasePage = (Invoke-WebRequest "https://api.github.com/repos/$repo/releases" | ConvertFrom-Json)
    $releaseFiltered = ($releasePage | Select-Object tag_name, prerelease, html_url, assets | Where-Object {$_.tag_name -match $fversion})[0]
  }
  $winAsset32 = $releaseFiltered.assets | Select-Object id, name, browser_download_url | Where-Object {$_.name -match "Windows_Portable_x86_32.zip"}
  $winAsset64 = $releaseFiltered.assets | Select-Object id, name, browser_download_url | Where-Object {$_.name -match "Windows_Portable_x86_64.zip"}
  Write-Debug "  Find asset x86_32: $($winAsset32.name)"
  Write-Debug "  Find asset x86_64: $($winAsset64.name)"
  $wc = [System.Net.WebClient]::new()
  $pkgurl32 = $winAsset32.browser_download_url
  $pkgurl64 = $winAsset64.browser_download_url
  $FileHash32 = Get-FileHash -InputStream ($wc.OpenRead($pkgurl32))
  $FileHash64 = Get-FileHash -InputStream ($wc.OpenRead($pkgurl64))
  Write-Debug "  FileHash x86_32: $($FileHash32.Hash)"
  Write-Debug "  FileHash x86_64: $($FileHash64.Hash)"
  return @{
    Version     = getNormVerion $releaseFiltered.tag_name
    ReleaseUrl  = $releaseFiltered.html_url
    URL32       = $winAsset32.browser_download_url
    SHA32       = $FileHash32.Hash
    URL64       = $winAsset64.browser_download_url
    SHA64       = $FileHash64.Hash
  }
}

function GetActual {
  param (
    [string]$packageId
  )

  Write-Debug "Get Chocolatey infos: $packageId"
  $chocoVersion = choco search $packageId --by-id-only --exact --limit-output
  if(!$chocoVersion) {
    Write-Error "Unable to find package on Chocolatey"
    return '0.0.0.0'
  }
  Write-Debug " Find Chocolatey infos: $chocoVersion"
  return $chocoVersion.split('|')[1]
}

function BackupFiles {
  param (
    [string[]]$FilesToBackup
  )

  Write-Debug "Backup $($FilesToBackup.Count) files"
  $backupedFiles = New-Object System.Collections.Generic.List[System.Object]
  New-Item -Name "bck" -ItemType "directory" | out-null

  for ($index = 0; $index -lt $FilesToBackup.count; $index++) {
    $FileToBackup = $FilesToBackup[$index].Replace('/', '_')
    Write-Debug " Copy-Item $($FilesToBackup[$index]) -Destination bck/$FileToBackup"
    Copy-Item $FilesToBackup[$index] -Destination "bck/$FileToBackup"
    $backupedFiles.Add($FileToBackup)
  }
  return $backupedFiles
}

function RestoreFiles {
  param (
    [string[]]$FilesToRestore
  )

  Write-Debug "Restore $($FilesToRestore.Count) files"
  for ($index = 0; $index -lt $FilesToRestore.count; $index++) {
    $FileToRestore = $FilesToRestore[$index].Replace('_', '/')
    Write-Debug " Copy-Item bck/$($FilesToRestore[$index]) -Destination $FileToRestore -Force"
    Copy-Item "bck/$($FilesToRestore[$index])" -Destination $FileToRestore -Force
  }
  Remove-Item "bck" -Recurse
}

###############################################################################
##              Start                                                        ##
###############################################################################
Write-Host "--------------------------------------------------"
Write-Host "Packaging WindTerm"
Write-Host "--------------------------------------------------"

$packageId          = 'windterm.portable'
$githubRepo         = 'kingToolbox/WindTerm'
$filesToUpdate      = 'windterm.nuspec', 'tools/chocolateyinstall.ps1'

## Get package and web version ##
$latestRelease = GetGithubInfos $githubRepo
$actualVersion = GetActual $packageId
Write-Host "Chocolatey version  : $actualVersion"
Write-Host "Github repo version : $($latestRelease.Version)"

## Check if packaging is needed ##
if($latestRelease.Version -like $actualVersion -And !$force) {
  Write-Warning "No new version available"
  exit
}
Write-Warning "Update available !"

## Display release informations ##
Write-Host "--------------------------------------------------"
Write-Host "Url32 : $($latestRelease.URL32)"
Write-Host "Sha32 : $($latestRelease.SHA32)"
Write-Host "Url64 : $($latestRelease.URL64)"
Write-Host "Sha64 : $($latestRelease.SHA64)"
Write-Host "--------------------------------------------------"

if(!$noPrompt) {
  $confirmation = Read-Host "Start packing [Y/n]?"
  $confirmation = ('y',$confirmation)[[bool]$confirmation]
  if($confirmation -eq 'n') {exit}
}

## Backup files
$backupedFiles = BackupFiles $filesToUpdate

## Replace informations in files ##
for ($index = 0; $index -lt $filesToUpdate.count; $index++) {
  Write-Debug "Update $($filesToUpdate[$index])"
  ReplaceInFile -FilePath $filesToUpdate[$index] `
                -SrcText '#REPLACE_VERSION#', '#REPLACE_RELEASE_INFO#', '#REPLACE_URL#', '#REPLACE_CHECKSUM#', '#REPLACE_URL_64#', '#REPLACE_CHECKSUM_64#' `
                -TargetText $latestRelease.Version, $latestRelease.ReleaseUrl, $latestRelease.URL32, $latestRelease.SHA32, $latestRelease.URL64, $latestRelease.SHA64
}

## Pack choco package ##
if(!$noPrompt) {
  Read-Host -Prompt "Files updated, press any key to continue"
}
Write-Debug "Starting 'choco pack'"
choco pack

## Restore files
RestoreFiles $backupedFiles
