param (
	[Parameter(Mandatory)][uint]$Index,
	[Parameter(ValueFromPipeline)][object]$InputObject
)


begin {
	$ErrorActionPreference = 'Stop'

	$i = 0
}
process {
	$isTarget = $i -eq $Index
	$i += 1
	if ($isTarget) {
		return $InputObject
	}
}
