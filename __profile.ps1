# STYLES
$PSStyle.FileInfo.Directory = $PSStyle.Foreground.Blue

function prompt {
	$location = (Get-Location).ProviderPath.Replace($env:HOMEDRIVE + $env:HOMEPATH, "~")
	[System.Console]::Title = "[pwsh : $PID] $(Split-Path $location -Leaf)"
	Write-Host "$env:USERNAME@$env:COMPUTERNAME" -ForegroundColor Green -NoNewline
	Write-Host " " -NoNewline
	Write-Host $location -ForegroundColor Cyan
	return ">> "
}

# AUTO CD
$ExecutionContext.InvokeCommand.CommandNotFoundAction = {
	param($CommandName, $CommandLookupEventArgs)

	$CommandName = $CommandName -replace '^get-', '' # ignore "get-" fallback
	if (Test-Path -LiteralPath $CommandName -PathType Container) {
		$CommandLookupEventArgs.CommandScriptBlock = {
			Set-Location -LiteralPath $CommandName
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
	if (-not (Test-Path -LiteralPath $CommandName -PathType Leaf)) {
		return
	}
	$destination = try { & "$PSScriptRoot\Get-Shortcut.ps1" -Path $CommandName } catch { $null }
	if ($destination -and (Test-Path -LiteralPath $destination -PathType Container)) {
		$CommandLookupEventArgs.CommandScriptBlock = {
			Set-Location -LiteralPath $destination
		}.GetNewClosure()
		$CommandLookupEventArgs.StopSearch = $true
	}
}

# ALIASES
foreach ($file in (Get-ChildItem -Path "$PSScriptRoot\*.ps1" -Exclude $MyInvocation.MyCommand.Name)) {
	Set-Alias -Name $file.BaseName -Value $file.FullName
}
Set-Alias -Name nth      -Value $PSScriptRoot\Get-Nth.ps1
Set-Alias -Name tostring -Value $PSScriptRoot\Get-String.ps1
Set-Alias -Name xi       -Value $PSScriptRoot\Explore-Item.ps1
Set-Alias -Name fi       -Value $PSScriptRoot\Find-Item.ps1
Set-Alias -Name oi       -Value $PSScriptRoot\Open-Item.ps1
