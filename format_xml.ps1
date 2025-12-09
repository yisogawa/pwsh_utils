param (
	[Parameter(ValueFromPipeline)][string] $Value
)

begin {
	$ErrorActionPreference = 'Stop'

	$values = [string]::Empty
}
process {
	# integrate multiline inputs from pipeline
	if ($values.Length -ne 0) {
		$values += [System.Environment]::NewLine
	}
	$values += $Value
}
end {
	$xdoc = [System.Xml.Linq.XDocument]::Parse($values)
	$xdoc.ToString()
}
