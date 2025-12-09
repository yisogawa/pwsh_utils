param (
	[Parameter(Mandatory, ValueFromPipeline)][string]$Path
)

begin {
	$ErrorActionPreference = 'Stop'
}
process {
	$dirPath = Split-Path $Path -Parent
	if ($dirPath -and -not (Test-Path $dirPath)) {
		New-Item -ItemType Directory -Path $dirPath
	}
	New-Item -ItemType File -Path $Path
}
