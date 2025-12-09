param (
	[Parameter(ParameterSetName = "Basic", Mandatory, Position = 0, ValueFromRemainingArguments)][string[]]$Keyword,
	[Parameter(ParameterSetName = "Regex", Mandatory)][string]$Regex,
	[Parameter(ValueFromPipeline)][string]$Target,
	[switch]$IgnoreCase,
	[switch]$Color,
	[switch]$Line
)

begin {
	$ErrorActionPreference = 'Stop'

	$regex = switch ($PSCmdlet.ParameterSetName) {
		"Basic" {
			[string]::Join(
				".*",
				($Keyword | ForEach-Object { "(" + [regex]::Escape($_) + ")" })
			)}
		"Regex" {
			$Regex
		}
	}
	$option = [System.Text.RegularExpressions.RegexOptions]::None
	if ($IgnoreCase) {
		$option = $option -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
	}
	$regexObj = [regex]::new($regex, $option)
	$l = 0
}
process {
	$l += 1
	$match = $regexObj.Match($Target)
	if (-not $match.Success) {
		return
	}

	$output = $_
	if ($Color) {
		$groups = switch ($PSCmdlet.ParameterSetName) {
			"Basic" {
				$match.Groups | Select-Object -Skip 1
			}
			"Regex" {
				$match.Groups
			}
		}
		foreach ($group in ($groups | Sort-Object { $_.Index } -Descending)) {
			$before = $output.Substring(0, $group.Index)
			$middle = $output.Substring($group.Index, $group.Length)
			$after = $output.Substring($group.Index + $group.Length)

			$output = $before + $PSStyle.Foreground.Black + $PSStyle.Background.BrightYellow + $middle + $PSStyle.Reset + $after
		}
	}
	if ($Line) {
		$output = [PSCustomObject]@{
			Line = $l
			Value = $output
		}
	}
	return $output
}
