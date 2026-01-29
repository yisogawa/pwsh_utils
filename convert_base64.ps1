param (
	[Parameter(Mandatory, ValueFromPipeline)][string]$InputString,
	[switch]$Decode,
	[System.Text.Encoding]$encoding = [System.Text.Encoding]::UTF8
)

if ([string]::IsNullOrEmpty($InputString)) {
	return [string]::Empty
}

if ($Decode) {
	$bytes = [System.Convert]::FromBase64String($InputString)
	return $encoding.GetString($bytes)
}
else {
	$bytes = $encoding.GetBytes($InputString)
	return [System.Convert]::ToBase64String($bytes)
}
