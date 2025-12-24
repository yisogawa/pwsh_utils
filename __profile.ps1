# STYLES
$PSStyle.FileInfo.Directory = $PSStyle.Foreground.Blue

[System.Console]::Title = "pwsh [$PID]"

function prompt {
	Write-Host "$env:USERNAME@$env:COMPUTERNAME" -ForegroundColor Green -NoNewline
	Write-Host " " -ForegroundColor DarkGray -NoNewline
	Write-Host (Get-Location).ProviderPath.Replace($env:HOMEDRIVE + $env:HOMEPATH, "~") -ForegroundColor Cyan
	return ">> "
}

# ALIASES
foreach ($file in (Get-ChildItem -Path "$PSScriptRoot\*.ps1" -Exclude $MyInvocation.MyCommand.Name)) {
	# convert snake_case to Pascal-Case
	$words = $file.BaseName -split "_" | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }
	$aliasName = $words -join "-"
	Set-Alias -Name $aliasName -Value $file.FullName
}
Set-Alias -Name nth      -Value $PSScriptRoot\get_nth.ps1
Set-Alias -Name tostring -Value $PSScriptRoot\get_string.ps1
Set-Alias -Name xi       -Value $PSScriptRoot\explore_item.ps1
Set-Alias -Name fi       -Value $PSScriptRoot\find_item.ps1
Set-Alias -Name oi       -Value $PSScriptRoot\open_item.ps1
