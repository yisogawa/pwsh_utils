param (
	[int]$Count = 1,
	[int]$Faces = 100
)

$ErrorActionPreference = 'Stop'

$Count = [System.Math]::Max($Count, 1)
$Faces = [System.Math]::Max($Faces, 1)

$result = 0
for ($i = 0; $i -lt $Count; $i += 1) {
	$result += Get-Random -Minimum 1 -Maximum ($Faces + 1)
}

return [PSCustomObject]@{
	Dice = "$($Count)D$Faces"
	Result = $result
}
