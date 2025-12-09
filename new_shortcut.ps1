using module .\mod\shortcut_manager.psm1

param (
	[Parameter(Mandatory)][string]$Name,
	[Parameter(Mandatory)][string]$TargetPath
)

$ErrorActionPreference = 'Stop'

return [ShortcutManager]::CreateShortcut($Name, $TargetPath)
