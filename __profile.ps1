# STYLES
$PSStyle.FileInfo.Directory = $PSStyle.Foreground.Blue

[System.Console]::Title = "pwsh [$PID]"

function prompt {
	Write-Host "$env:USERNAME@$env:COMPUTERNAME" -ForegroundColor Green -NoNewline
	Write-Host " " -NoNewline
	Write-Host (Get-Location).ProviderPath.Replace($env:HOMEDRIVE + $env:HOMEPATH, "~") -ForegroundColor Cyan
	return ">> "
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
