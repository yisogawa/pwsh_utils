using module .\mod\file_system.psm1

# STYLES
$PSStyle.FileInfo.Directory = $PSStyle.Foreground.Blue

function prompt {
	$location = (Get-Location).ProviderPath.Replace($env:HOMEDRIVE + $env:HOMEPATH, "~")
	[System.Console]::Title = "pwsh ($(Split-Path $location -Leaf))"
	Write-Host "$env:USERNAME@$env:COMPUTERNAME" -ForegroundColor Green -NoNewline
	Write-Host " " -NoNewline
	Write-Host $location -ForegroundColor Cyan
	return ">> "
}

# ERROR HANDLING
$ErrorActionPreference = 'Stop'

# AUTO CD
$ExecutionContext.InvokeCommand.CommandNotFoundAction = {
	param($CommandName, $CommandLookupEventArgs)

	$CommandName = $CommandName -replace '^get-', '' # ignore "get-" fallback
	$fs = [FileSystem]::new()
	if ($fs.IsDirectory($CommandName)) {
		$CommandLookupEventArgs.CommandScriptBlock = {
			[void]$fs.SetCurrentDir($CommandName)
		}.GetNewClosure()
	}
	$CommandLookupEventArgs.StopSearch = $true
}
# shortcuts to directories are hooked before lookup, since ".\foo.lnk" would be found as an application
$ExecutionContext.InvokeCommand.PreCommandLookupAction = {
	param($CommandName, $CommandLookupEventArgs)

	if (-not $CommandName.EndsWith(".lnk", [System.StringComparison]::OrdinalIgnoreCase)) {
		return
	}
	$fs = [FileSystem]::new()
	$destination = try { $fs.ResolvePath($CommandName, $true) } catch { $null }
	if ($destination -and $fs.IsDirectory($destination)) {
		$CommandLookupEventArgs.CommandScriptBlock = {
			[void]$fs.SetCurrentDir($destination)
		}.GetNewClosure()
		$CommandLookupEventArgs.StopSearch = $true
	}
}

# ALIASES
foreach ($file in (Get-ChildItem -Path "$PSScriptRoot\*.ps1" -Exclude $MyInvocation.MyCommand.Name)) {
	Set-Alias -Name $file.BaseName -Value $file.FullName
}
Set-Alias -Name nth      -Value $PSScriptRoot\Get-Nth.ps1
Set-Alias -Name xi       -Value $PSScriptRoot\Show-ItemExplorer.ps1
Set-Alias -Name fi       -Value $PSScriptRoot\Find-Item.ps1
Set-Alias -Name oi       -Value $PSScriptRoot\Open-Item.ps1
