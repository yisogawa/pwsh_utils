param (
	[Parameter(Mandatory, ValueFromPipeline)][string]$InputString,
	[switch]$Decode
)

if ([string]::IsNullOrEmpty($InputString)) {
	return [string]::Empty
}

if ($Decode) {
	return [System.Web.HttpUtility]::UrlDecode($InputString)
}
else {
	return [System.Web.HttpUtility]::UrlEncode($InputString)
}
