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
		$currentDir = $this.GetCurrentDir()
		if ($currentDir -eq $this.SYS_ROOT_PATH) {
			return $currentDir
		}
		$separator = [System.IO.Path]::DirectorySeparatorChar
		$homeDir = (Resolve-Path -LiteralPath "~").ProviderPath.TrimEnd($separator)
		if ([string]::Equals($currentDir, $homeDir, [System.StringComparison]::OrdinalIgnoreCase)) {
			return "~"
		}
		if ($currentDir.StartsWith($homeDir + $separator, [System.StringComparison]::OrdinalIgnoreCase)) {
			return "~" + $currentDir.Substring($homeDir.Length)
		}
		return $currentDir
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
	[bool] Exists([string]$path) {
		return Test-Path -LiteralPath $path
	}
	[bool] IsValidItemName([string]$name) {
		return -not (
			[string]::IsNullOrWhiteSpace($name) -or
			$name.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
			$name.Contains([System.IO.Path]::DirectorySeparatorChar) -or
			$name.Contains([System.IO.Path]::AltDirectorySeparatorChar) -or
			$name -in @('.', '..')
		)
	}
	[bool] IsRelativePath([string]$path) {
		# true if the path depends on the current directory.
		return -not (
			$path -eq $this.SYS_ROOT_PATH -or
			$path -eq "~" -or
			$path.StartsWith("~" + [System.IO.Path]::DirectorySeparatorChar) -or
			$path.StartsWith("~" + [System.IO.Path]::AltDirectorySeparatorChar) -or
			[System.IO.Path]::IsPathFullyQualified($path)
		)
	}
	[string] ResolveDestination([string]$path) {
		# resolves a path that may not exist yet, following PowerShell rules (e.g. "~").
		return $global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
	}
	[string] GetChildPath([string]$name) {
		if ($this.virtualCurrentDir -eq $this.SYS_ROOT_PATH) {
			throw [System.InvalidOperationException]::new("The virtual root cannot contain items")
		}
		if (-not $this.IsValidItemName($name)) {
			throw [System.ArgumentException]::new("Invalid item name: $name")
		}
		return [System.IO.Path]::Join($this.GetCurrentDir(), $name)
	}
	[void] OpenFile([string]$path) {
		explorer.exe $path
	}
	[void] CopyItem([string]$source, [string]$destination, [bool]$force) {
		if ($force) {
			Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
		}
		else {
			Copy-Item -LiteralPath $source -Destination $destination -Recurse
		}
	}
	[void] MoveItem([string]$source, [string]$destination, [bool]$force) {
		if ($force) {
			Move-Item -LiteralPath $source -Destination $destination -Force
		}
		else {
			Move-Item -LiteralPath $source -Destination $destination
		}
	}
	[void] DeleteItem([string]$path) {
		Remove-Item -LiteralPath $path -Recurse -Force
	}
	[void] NewFile([string]$path) {
		New-Item -ItemType File -Path $path | Out-Null
	}
	[void] NewDirectory([string]$path) {
		New-Item -ItemType Directory -Path $path | Out-Null
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
		$item = Get-Item -LiteralPath $path -Force
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
