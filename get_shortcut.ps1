using module .\mod\shortcut_manager.psm1

param (
	[Parameter(ValueFromPipeline, Mandatory)][string]$Path,
	[switch]$AsObject
)

begin {
	$ErrorActionPreference = 'Stop'

	$sm = [ShortcutManager]::new()
}
process {
	if ($AsObject) {
		return $sm.OpenShortcut($Path)
	}
	else {
		return $sm.GetShortcutTarget($Path)
	}
}
