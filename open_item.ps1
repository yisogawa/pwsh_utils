using module .\mod\file_system.psm1

param (
	[Parameter(ValueFromPipeline, Mandatory)]$Path
)

begin {
	$fs = [FileSystem]::new()
}
process {
	$path = $fs.ResolvePath($Path, $true)
	if ($fs.IsDirectory($path)) {
		$fs.SetCurrentDir($path) | Out-Null
		return Get-ChildItem -Force
	}
	else {
		$fs.OpenFile($path)
	}
}
