param (
	[Parameter(Mandatory, ValueFromPipeline)][string]$InputString,
	[switch]$Decode
)

$CP_ESC = @{
	0x0000 = '\0'
	0x0007 = '\a'
	0x0008 = '\b'
	0x0009 = '\t'
	0x000A = '\n'
	0x000B = '\v'
	0x000C = '\f'
	0x000D = '\r'
	0x001B = '\e'
	0x0022 = '\"'
	0x0027 = '\'''
	0x005C = '\\'
}

$ESC_CP = @{
	'\0'  = 0x0000
	'\a'  = 0x0007
	'\b'  = 0x0008
	'\t'  = 0x0009
	'\n'  = 0x000A
	'\v'  = 0x000B
	'\f'  = 0x000C
	'\r'  = 0x000D
	'\e'  = 0x001B
	'\"'  = 0x0022
	'\''' = 0x0027
	'\\'  = 0x005C
}

if ([string]::IsNullOrEmpty($InputString)) {
	return [string]::Empty
}

if ($Decode) {
	$s = $InputString
	$s = [regex]::Replace($s, [string]::Join("|", ($ESC_CP.Keys | ForEach-Object { [regex]::Escape($_) })), {
			param ($match)
			$codepoint = $ESC_CP[$match.Value]
			[char]$codepoint
		})
	$s = [regex]::Replace($s, '\\u(?<hex>[0-9A-Fa-f]{0,4})', {
			param ($match)
			$hex = $match.Groups['hex']
			$codepoint = [System.Convert]::ToInt32($hex, 16)
			[char]$codepoint
		})
	$s = [regex]::Replace($s, '\\U(?<hex>[0-9A-Fa-f]{0,8})', {
			param ($match)
			$hex = $match.Groups['hex']
			$codepoint = [System.Convert]::ToInt32($hex, 16)
			[char]::ConvertFromUtf32($codepoint)
		})
	return $s
}
else {
	$sb = [System.Text.StringBuilder]::new()
	foreach ($c in $InputString.ToCharArray()) {
		if ($CP_ESC.ContainsKey([int]$c)) {
			$null = $sb.Append($CP_ESC[[int]$c])
		}
		elseif ([char]::IsControl($c)) {
			$null = $sb.Append('\u' + ([int]$c).ToString('X4'))
		}
		else {
			$null = $sb.Append($c)
		}
	}
	return $sb.ToString()
}
