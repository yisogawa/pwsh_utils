using module .\mod\file_system.psm1

param (
	[Parameter(Position = 0, ValueFromRemainingArguments)][string[]]$Keyword
)

$fs = [FileSystem]::new()
$fs.GetChildItems($Keyword -join " ")
