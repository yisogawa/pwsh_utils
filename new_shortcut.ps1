using module .\mod\shortcut_manager.psm1

param (
	[Parameter(Mandatory)][string]$Name,
	[Parameter(Mandatory)][string]$TargetPath
)

$ErrorActionPreference = 'Stop'

$sm = [ShortcutManager]::new()
return $sm.CreateShortcut($Name, $TargetPath)
