$installDir = Join-Path (Get-ToolsLocation) "Windterm"
Remove-Item $installDir -Recurse

$desktopPath = [Environment]::GetFolderPath("Desktop")
Remove-Item "$desktopPath\WindTerm.lnk" -ErrorAction SilentlyContinue -Force
