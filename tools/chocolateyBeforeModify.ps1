$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$oldDir = Get-ChildItem "$toolsDir" -recurse | Where-Object {$_.PSIsContainer -eq $true -and $_.Name -match "WindTerm_"}
if($oldDir) {
  $oldProfilesDir = "$toolsDir\$oldDir\profiles"
  if (Test-Path -Path $oldProfilesDir) {
    Copy-Item "$oldProfilesDir/" -Destination "$toolsDir/bck_profiles/" -Recurse
  }
}
