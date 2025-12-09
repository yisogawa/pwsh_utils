param (
	[Parameter(ValueFromPipeline)][string] $Value,
	[switch]$Compress,
	[int]$IndentSize = 4
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
	$option = [System.Text.Json.JsonSerializerOptions]::new()
	$option.Encoder = [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping
	$option.WriteIndented = -not $Compress
	$option.IndentSize = $IndentSize

	$jsonObj = [System.Text.Json.JsonSerializer]::Deserialize[object]($values)
	return [System.Text.Json.JsonSerializer]::Serialize($jsonObj, $option)
}
