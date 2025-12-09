param (
	[Parameter(ValueFromPipeline)][object]$Value
)

process {
	if ($null -eq $Value) {
		return $null
	}
	return $Value.ToString()
}
