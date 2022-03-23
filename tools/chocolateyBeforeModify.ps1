$ErrorActionPreference = 'Stop'

$installDir = Join-Path (Get-ToolsLocation) "Windterm"

$oldDir = Get-ChildItem "$installDir" -recurse | Where-Object {$_.PSIsContainer -eq $true -and $_.Name -match "WindTerm.portable"}
if($oldDir) {
  $oldProfilesDir = "$installDir\$oldDir\profiles"
  if (Test-Path -Path $oldProfilesDir) {
    Copy-Item "$oldProfilesDir/" -Destination "$installDir/bck_profiles/" -Recurse
  }
}
