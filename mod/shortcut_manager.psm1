$ErrorActionPreference = 'Stop'

class ShortcutManager {
	static [object] OpenShortcut([string]$path) {
		$path = (Resolve-Path -LiteralPath $path).ProviderPath
		$wss = [ShortcutManager]::_CreateWSS()
		return $wss.CreateShortcut($path)
	}
	static [string] GetShortcutTarget([string]$path) {
		$shortcut = [ShortcutManager]::OpenShortcut($path)
		return $shortcut.TargetPath
	}
	static [object] CreateShortcut([string]$path, [string]$targetPath) {
		if ($path.ToLower().EndsWith(".lnk")) {
			$targetPath = (Resolve-Path -LiteralPath $targetPath).ProviderPath
		}

		$wss = [ShortcutManager]::_CreateWSS()
		$shortcut = $wss.CreateShortcut($path)
		$shortcut.TargetPath = $targetPath
		$shortcut.Save()
		return $shortcut
	}
	static [object] _CreateWSS() {
		$wss = New-Object -ComObject WScript.Shell
		$wss.CurrentDirectory = (Get-Location).ProviderPath
		return $wss
	}
}
