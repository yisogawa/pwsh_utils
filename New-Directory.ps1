Param (
	[Parameter(Mandatory, ValueFromPipeline)][string]$Path
)

begin {
	$ErrorActionPreference = 'Stop'
}
process {
	New-Item -ItemType Directory -Path $Path
}
