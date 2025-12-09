class ShortcutManager {
	$wss = (New-Object -ComObject WScript.Shell)

	[object] OpenShortcut([string]$path) {
		$path = (Resolve-Path -LiteralPath $path).ProviderPath
		return $this.wss.CreateShortcut($path)
	}
	[string] GetShortcutTarget([string]$path) {
		return $this.OpenShortcut($path).TargetPath
	}
	[object] CreateShortcut([string]$path, [string]$targetPath) {
		$path = (Resolve-Path -LiteralPath $path).ProviderPath
		if ($path.ToLower().EndsWith(".lnk")) {
			$targetPath = (Resolve-Path -LiteralPath $targetPath).ProviderPath
		}

		$shortcut = $this.wss.CreateShortcut($path)
		$shortcut.TargetPath = $targetPath
		$shortcut.Save()
		return $shortcut
	}
}
