using module .\shortcut_manager.psm1

$ErrorActionPreference = 'Stop'

class FileSystem {
	[string]$SYS_ROOT_PATH = "<root>"
	[string]$virtualCurrentDir = $null

	[string] GetCurrentDir() {
		if ($this.virtualCurrentDir) {
			return $this.virtualCurrentDir
		}
		return (Get-Location).ProviderPath
	}
	[string] GetDisplayCurrentDir() {
		$homeDir = (Resolve-Path -LiteralPath "~").ProviderPath
		return $this.GetCurrentDir().Replace($homeDir, "~")
	}
	[bool] SetCurrentDir([string]$path) {
		if ($path -eq $this.SYS_ROOT_PATH) {
			$this.virtualCurrentDir = $this.SYS_ROOT_PATH
			return $true
		}
		if ($path -in @("..", "..\")) {
			if ($this.virtualCurrentDir -eq $this.SYS_ROOT_PATH) {
				return $false
			}
			if ($this._AtRootOfDrive()) {
				$this.virtualCurrentDir = $this.SYS_ROOT_PATH
				return $true
			}
		}
		$this.virtualCurrentDir = $null
		Set-Location -LiteralPath $path
		return $true
	}
	[bool] IsDirectory([string]$path) {
		if ($path -eq $this.SYS_ROOT_PATH) {
			return $true
		}
		return Test-Path -LiteralPath $path -PathType Container
	}
	[void] OpenFile([string]$path) {
		explorer.exe $path
	}
	[array] GetChildItems() {
		if ($this.virtualCurrentDir -eq $this.SYS_ROOT_PATH) {
			return [System.IO.DriveInfo]::GetDrives()
		}
		return Get-ChildItem -Force
	}
	[array] GetChildItems([string]$query) {
		$keywords = [regex]::Matches($query, "\S+").Value
		$escapedKeywords = $keywords
		| Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
		| ForEach-Object { [regex]::Escape($_) }

		$partialMatchQuery = [regex]::new(
			($escapedKeywords -join ".*"), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
		)
		$prefixMatchQuery = [regex]::new(
			"^" + ($escapedKeywords -join ".*"), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
		)

		return $this.GetChildItems()
		| Where-Object { $partialMatchQuery.IsMatch($_.Name) }
		| Sort-Object { $prefixMatchQuery.IsMatch($_.Name) } -Descending -Stable
	}
	[string] ResolvePath([string]$path, [bool]$traceShortcutTarget) {
		if ($path -eq $this.SYS_ROOT_PATH) {
			return $path
		}
		$item = Get-Item $path -Force
		if ($traceShortcutTarget) {
			if ($item.GetType() -eq [System.IO.FileInfo] -and $item.Extension -eq ".lnk") {
				$targetPath = [ShortcutManager]::GetShortcutTarget($path)
				return $this.ResolvePath($targetPath, $true)
			}
		}
		return $item.FullName
	}
	[bool] _AtRootOfDrive() {
		try {
			$root = (Resolve-Path -LiteralPath "\").ProviderPath # may fail on network storage
			return $this.GetCurrentDir() -eq $root
		}
		catch {
			return $false
		}
	}
}
