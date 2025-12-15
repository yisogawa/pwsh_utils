using module .\mod\shortcut_manager.psm1

param (
	[Parameter(ValueFromPipeline, Mandatory)][string]$Path,
	[switch]$AsObject
)

begin {
	$ErrorActionPreference = 'Stop'
}
process {
	if ($AsObject) {
		return [ShortcutManager]::OpenShortcut($Path)
	}
	else {
		return [ShortcutManager]::GetShortcutTarget($Path)
	}
}
