$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
Remove-Item $toolsDir -Recurse

$desktopPath = [Environment]::GetFolderPath("Desktop")
Remove-Item "$desktopPath\WindTerm.lnk" -ErrorAction SilentlyContinue -Force
