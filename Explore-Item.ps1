using module .\mod\file_system.psm1

param (
	[string]$Path = ".",
	[switch]$Help
)

# --------------------------------------------------
# preferences
# --------------------------------------------------
$ErrorActionPreference = 'Stop'

if ($Help) {
	@'
Explore-Item.ps1 [-Path <path>] [-Help]

Interactively searches and operates on files and directories.

Normal mode
  Type text               Filter items by node name
  Up/Down, PageUp/PageDown
                          Move the selection
  Enter                   Open a file or enter a directory
  Alt+Up, Ctrl+U          Move to the parent directory
  Alt+Left, Ctrl+B        Go back in directory history
  Alt+Right, Ctrl+F       Go forward in directory history
  Ctrl+R                  Reload the item list
  /                       Enter command mode
  Esc, Ctrl+C             Exit

Command mode
  Enter                   Execute the command
  Esc                     Discard the command and return to normal mode

Commands
  /q                      Exit
  /h, /help               Open this help in a new PowerShell process
  /r                      Reload the item list
  /b, /f                  Go back or forward in directory history
  /cp                     Copy the current directory path to the clipboard
  /c                      Copy the selected item path to the clipboard
  /c <path>               Copy the selected item
  /cf <path>              Copy and allow overwriting an existing file
  /m <path>               Move or rename the selected item
  /mf <path>              Move or rename and allow overwriting a file
  /d                      Delete the selected item without confirmation
  /nf <name>              Create an empty file in the current directory
  /nd <name>              Create a directory in the current directory

Paths containing spaces may be entered directly or surrounded by matching
single or double quotes. When a copy or move destination is a directory, the
selected item is placed inside that directory.

Error display
  Esc                     Discard the command and return to normal mode
  Any other key           Return to command mode and retain the command
'@ | Write-Host
	return
}

# --------------------------------------------------
# classes
# --------------------------------------------------
class ConsoleReader : System.IDisposable {
	$prevTreatControlCAsInput

	ConsoleReader() {
		$this.prevTreatControlCAsInput = [System.Console]::TreatControlCAsInput

		[System.Console]::TreatControlCAsInput = $true
	}
	[bool] KeyAvailable() {
		return [System.Console]::KeyAvailable
	}
	[System.ConsoleKeyInfo] ReadKey() {
		return [System.Console]::ReadKey($true)
	}
	# impl for System.IDisposable
	[void] Dispose() {
		[System.Console]::TreatControlCAsInput = $this.prevTreatControlCAsInput
	}
}

class ConsoleWriter : System.IDisposable {
	$CMD = @{ # ANSI escape codes
		ENTER_ALTERNATE_SCREEN_BUF = [char]0x1B + "[?1049h"
		LEAVE_ALTERNATE_SCREEN_BUF = [char]0x1B + "[?1049l"
		ERASE_TO_END_OF_LINE       = [char]0x1B + "[K"
		ERASE_TO_END_OF_SCREEN     = [char]0x1B + "[0J"
		SAVE_CURSOR_POS            = [char]0x1B + "7"
		RESTORE_CURSOR_POS         = [char]0x1B + "8"
		MOVE_CURSOR_TO_NEW_LINE    = [char]0x1B + "[1E"
	}
	$prevCursorVisible
	$prevTitle
	$prevOutputRendering

	ConsoleWriter() {
		$this.prevCursorVisible = [System.Console]::CursorVisible
		$this.prevTitle = [System.Console]::Title
		$this.prevOutputRendering = $Global:PSStyle.OutputRendering

		[System.Console]::CursorVisible = $false
		$Global:PSStyle.OutputRendering = 'Ansi'

		[Console]::Write($this.CMD.ENTER_ALTERNATE_SCREEN_BUF)
		[System.Console]::Clear()
	}
	[int] WindowWidth() {
		return [System.Console]::WindowWidth
	}
	[int] WindowHeight() {
		return [System.Console]::WindowHeight
	}
	[int[]] CursorPosition() {
		return ([System.Console]::CursorLeft, [System.Console]::CursorTop)
	}
	[void] SetCursorPosition([int[]]$leftTop) {
		[System.Console]::SetCursorPosition($leftTop[0], $leftTop[1])
	}
	[void] SetCursorPosition([int]$left, [int]$top) {
		[System.Console]::SetCursorPosition($left, $top)
	}
	[void] ShowCursor() {
		[System.Console]::CursorVisible = $true
	}
	[void] HideCursor() {
		[System.Console]::CursorVisible = $false
	}
	[void] SetTitle([string]$title) {
		[System.Console]::Title = $title
	}
	[void] Print([string]$text) {
		[System.Console]::Write($text)
	}
	[void] PrintLn([string]$text) {
		# NOTE: erase line content before write text to avoid deleting written char at right end of screen.
		#
		# writing text to fill console line, cursor position will be at right end of screen.
		# | <-- screen --> |
		# |AAAAAAAAAAAAAAAA| <-- text
		# |               _| <-- cursor position
		#
		# erase code deletes last 'A' in this circumstance.
		# | <-- screen --> |
		# |AAAAAAAAAAAAAAA | <-- text
		# |               _| <-- cursor position

		$top = [System.Console]::CursorTop
		[System.Console]::Write(
			$this.CMD.SAVE_CURSOR_POS +
			$this.CMD.ERASE_TO_END_OF_LINE +
			$text
		)
		$lnMove = [System.Console]::CursorTop -ne $top

		if ($lnMove) {
			[System.Console]::Write(
				$this.CMD.ERASE_TO_END_OF_LINE +
				$this.CMD.RESTORE_CURSOR_POS +
				$text
			)
		}

		if ([System.Console]::CursorTop -lt [System.Console]::WindowHeight - 1) {
			[System.Console]::Write($this.CMD.MOVE_CURSOR_TO_NEW_LINE)
		}
	}
	[void] Clear() {
		[System.Console]::Clear()
	}
	[void] ClearToEndOfScreen() {
		[Console]::Write($this.CMD.ERASE_TO_END_OF_SCREEN)
	}
	# impl for System.IDisposable
	[void] Dispose() {
		[System.Console]::CursorVisible = $this.prevCursorVisible
		[System.Console]::Title = $this.prevTitle
		$Global:PSStyle.OutputRendering = $this.prevOutputRendering

		[Console]::Write($this.CMD.LEAVE_ALTERNATE_SCREEN_BUF)
	}
}

class InputBox {
	[string]$value = ""
	[int]$cursorPos = 0

	InputBox() {}
	[string] Text() {
		return $this.value
	}
	[string] TextBeforeCursor() {
		return $this.value.Substring(0, $this.cursorPos)
	}
	[string] TextAfterCursor() {
		return $this.value.Substring($this.cursorPos)
	}
	[void] MoveCursorLeft() {
		if ($this.cursorPos -gt 0) {
			$this.cursorPos -= 1
		}
	}
	[void] MoveCursorRight() {
		if ($this.cursorPos -lt $this.value.Length) {
			$this.cursorPos += 1
		}
	}
	[void] MoveCursorToLeftEnd () {
		$this.cursorPos = 0
	}
	[void] MoveCursorToRightEnd () {
		$this.cursorPos = $this.value.Length
	}
	[void] InsertChar([char]$value) {
		$c = $value
		if ([char]::IsControl($c)) { return }
		if ([char]::IsWhiteSpace($c)) { $c = [char]" " }

		$this.value = $this.value.Insert($this.cursorPos, $c)
		$this.cursorPos += 1
	}
	[void] InsertString([string]$value) {
		foreach ($c in $value.ToCharArray()) {
			$this.InsertChar($c)
		}
	}
	[void] DeleteLeft() {
		if ($this.cursorPos -gt 0) {
			$this.value = $this.value.Remove($this.cursorPos - 1, 1)
			$this.cursorPos -= 1
		}
	}
	[void] DeleteRight() {
		if ($this.cursorPos -lt $this.value.Length) {
			$this.value = $this.value.Remove($this.cursorPos, 1)
		}
	}
	[void] TruncateLeft() {
		$this.value = $this.value.Substring($this.cursorPos)
		$this.cursorPos = 0
	}
	[void] TruncateRight() {
		$this.value = $this.value.Substring(0, $this.cursorPos)
	}
	[void] Clear() {
		$this.value = ""
		$this.cursorPos = 0
	}
}

enum AppMode {
	Normal
	Command
	Error
}

enum InputResult {
	Continue
	RestartLoop
	Exit
}

class AppState {
	[AppMode]$Mode = [AppMode]::Normal
	[InputBox]$QueryInput = [InputBox]::new()
	[InputBox]$CommandInput = [InputBox]::new()
	[string]$ErrorMessage = ""
	[bool]$ItemListInvalidated = $true
}

class CommandValidationException : System.Exception {
	CommandValidationException([string]$message) : base($message) {}
}

class ListViewer {
	[int] $DESIRED_MARGIN = 2

	[array] $items = @()
	[int] $viewHeight = 10
	[int] $selected = 0
	[int] $viewTop = 0 # follows `selected`

	PagedList() {}
	[bool] Any() {
		return $this.items.Count -gt 0
	}
	[int] SelectedRow() {
		return $this.selected - $this.viewTop
	}
	[object] SelectedItem() {
		if ($this.Any()) {
			return $this.items[$this.selected]
		}
		return $null
	}
	[array] VisibleItems() {
		$startIndex = $this.viewTop
		$endIndex = [System.Math]::Min($startIndex + $this.viewHeight, $this.items.Count)
		return $this.items[$startIndex..($endIndex - 1)]
	}
	[void] SetItems([array]$value) {
		$this.items = $value ?? @()
		$this.selected = 0
		$this.viewTop = 0
	}
	[void] SetViewHeight([int]$value) {
		$this.viewHeight = $value
		$this.viewTop = $this._CalcViewTop()
	}
	[void] SelectNext() {
		$this._SetSelected($this.selected + 1)
	}
	[void] SelectPrev() {
		$this._SetSelected($this.selected - 1)
	}
	[void] SelectNextPage() {
		$this._SetSelected($this.selected + $this.viewHeight)
	}
	[void] SelectPrevPage() {
		$this._SetSelected($this.selected - $this.viewHeight)
	}
	[void] SelectFirst() {
		$this._SetSelected(0)
	}
	[void] SelectLast() {
		$this._SetSelected($this.items.Count - 1)
	}
	[void] _SetSelected([int]$value) {
		$value = [System.Math]::Max($value, 0)
		$value = [System.Math]::Min($value, $this.items.Count - 1)

		$this.selected = $value
		$this.viewTop = $this._CalcViewTop()
	}
	[int] _CalcViewTop() {
		$margin = $this._CalcMargin()

		# scroll up if selected item is above the visible area
		if ($this.selected -lt $this.viewTop + $margin) {
			return [System.Math]::Max($this.selected - $margin, 0)
		}

		# scroll down if selected item is below the visible area
		$viewBottom = $this.viewTop + $this.viewHeight - 1
		if ($this.selected -gt $viewBottom - $margin) {
			$viewBottom = $this.selected + $margin
			return $viewBottom - $this.viewHeight + 1
		}

		return $this.viewTop
	}
	[int] _CalcMargin() {
		return [System.Math]::Min(
			$this.DESIRED_MARGIN,
			[System.Math]::Floor(($this.viewHeight - 1) / 2)
		)
	}
}

class History {
	[array] $entries = @()
	[int] $currentIndex = 0

	History() {}
	[void] Do([object]$entry) {
		$this.entries = $this.entries[0..($this.currentIndex)] # discard future entries
		$this.entries += $entry
		$this.currentIndex = $this.entries.Count - 1
	}
	[object] Undo() {
		if ($this.currentIndex -gt 0) {
			$this.currentIndex -= 1
			return $this.entries[$this.currentIndex]
		}
		return $null
	}
	[object] Redo() {
		if ($this.currentIndex -lt $this.entries.Count - 1) {
			$this.currentIndex += 1
			return $this.entries[$this.currentIndex]
		}
		return $null
	}
}

# --------------------------------------------------
# main logic
# --------------------------------------------------
try {
	$fs = [FileSystem]::new()
	$cin = [ConsoleReader]::new()
	$cout = [ConsoleWriter]::new()

	$history = [History]::new()
	$state = [AppState]::new()
	$itemList = [ListViewer]::new()

	$Path = $fs.ResolvePath($Path, $true)
	if ($fs.IsDirectory($Path)) {
		$fs.SetCurrentDir($Path) | Out-Null
	}
	else {
		$fs.SetCurrentDir(($Path | Split-Path -Parent)) | Out-Null
		$state.QueryInput.InsertString(($Path | Split-Path -Leaf))
	}
	$history.Do($fs.GetCurrentDir())

	function updateItemList() {
		if (-not $state.ItemListInvalidated) {
			return
		}

		$itemList.SetItems($fs.GetChildItems($state.QueryInput.Text()))
		$state.ItemListInvalidated = $false
	}

	function render() {
		$currentDir = $fs.GetCurrentDir()
		$dirName = if ($currentDir -eq $fs.SYS_ROOT_PATH) {
			$currentDir
		}
		else {
			[System.IO.DirectoryInfo]::new($currentDir).Name
		}
		$cout.SetTitle($dirName + " - xi")

		$cout.HideCursor()
		$cout.SetCursorPosition(0, 0)

		# render current dir
		$cout.PrintLn($PSStyle.Foreground.Cyan + $fs.GetDisplayCurrentDir() + $Global:PSStyle.Reset)

		# render the active input at the same position in every mode
		switch ($state.Mode) {
			([AppMode]::Normal) {
				$cout.Print("? " + $state.QueryInput.TextBeforeCursor())
				$desiredCursorPosition = $cout.CursorPosition()
				$cout.PrintLn($state.QueryInput.TextAfterCursor())
			}
			([AppMode]::Command) {
				$cout.Print("/ " + $state.CommandInput.TextBeforeCursor())
				$desiredCursorPosition = $cout.CursorPosition()
				$cout.PrintLn($state.CommandInput.TextAfterCursor())
			}
			([AppMode]::Error) {
				$cout.Print($PSStyle.Foreground.Red + "! ")
				$desiredCursorPosition = $cout.CursorPosition()
				$cout.PrintLn($state.ErrorMessage + $Global:PSStyle.Reset)
			}
		}

		# render item list
		($cursorLeft, $cursorTop) = $cout.CursorPosition()
		$headerHeight = 2
		$itemList.SetViewHeight($cout.WindowHeight() - $headerHeight - $cursorTop)
		if ($itemList.Any()) {
			$itemList.VisibleItems()
			| ForEach-Object {
				$size = if ($_.LengthString) {
					$suffix = @("[ B]", "[KB]", "[MB]", "[GB]", "[TB]")
					$size = $_.Length
					for ($i = 0; $i -lt $suffix.Count; $i++) {
						$digit = [System.Math]::Pow(1000, $i)
						if ($size -lt (1000 * $digit)) {
							break
						}
					}
					[System.Math]::Floor($size / $digit).ToString() + $suffix[$i]
				}
				else {
					$null
				}

				$style = $_.PSIsContainer ? $PSStyle.FileInfo.Directory : $PSStyle.FileInfo.File
				$style += ($_ -eq $itemList.SelectedItem()) ? $PSStyle.Reverse : ""

				[PSCustomObject]@{
					LastWriteTime = $_.LastWriteTime
					Size          = $size
					Name          = $style + $_.Name + $Global:PSStyle.Reset
				}
			}
			| Format-Table -Wrap:$false -Property `
			@{
				Label        = "LastWriteTime"
				Expression   = { $_.LastWriteTime }
				FormatString = "yyyy-MM-dd HH:mm"
				Width        = 16
				Alignment    = "Left"
			},
			@{
				Label      = "Size"
				Expression = { $_.Size }
				Width      = 7
				Alignment  = "Right"
			},
			@{
				Label      = "Name"
				Expression = { $_.Name }
				Alignment  = "Left"
			}
			| Out-String -Stream -Width ($cout.WindowWidth() - 1) # -1 to absorb environmental differences in handling the '…' character (U+2026).
			| Where-Object { -not[string]::IsNullOrEmpty($_) }
			| ForEach-Object { $cout.PrintLn($_) }
		}
		else {
			$cout.PrintLn($Global:PSStyle.Dim + "-- NO ITEM --" + $Global:PSStyle.DimOff)
		}
		$cout.ClearToEndOfScreen()

		if ($state.Mode -eq [AppMode]::Error) {
			$cout.HideCursor()
		}
		else {
			$cout.SetCursorPosition($desiredCursorPosition)
			$cout.ShowCursor()
		}
	}

	function processTextInput([InputBox]$target, [System.ConsoleKeyInfo]$key) {
		switch ($key.Modifiers) {
			([System.ConsoleModifiers]::Control) {
				switch ($key.Key) {
					'LeftArrow' { $target.MoveCursorToLeftEnd() }
					'RightArrow' { $target.MoveCursorToRightEnd() }
					'Backspace' { $target.TruncateLeft() }
					'Delete' { $target.TruncateRight() }
				}
			}
			default {
				switch ($key.Key) {
					'LeftArrow' { $target.MoveCursorLeft() }
					'RightArrow' { $target.MoveCursorRight() }
					'Home' { $target.MoveCursorToLeftEnd() }
					'End' { $target.MoveCursorToRightEnd() }
					'Backspace' { $target.DeleteLeft() }
					'Delete' { $target.DeleteRight() }
					default { $target.InsertChar($key.keyChar) }
				}
			}
		}
	}

	function processQueryInput([System.ConsoleKeyInfo]$key) {
		$before = $state.QueryInput.Text()
		processTextInput $state.QueryInput $key
		if ($state.QueryInput.Text() -ne $before) {
			$state.ItemListInvalidated = $true
		}
	}

	function processInput([System.ConsoleKeyInfo]$key) {
		# ConsoleReader turns Ctrl+C into input, so handle it before mode dispatch.
		if (
			$key.Key -eq [System.ConsoleKey]::C -and
			$key.Modifiers -eq [System.ConsoleModifiers]::Control
		) {
			return [InputResult]::Exit
		}

		switch ($state.Mode) {
			([AppMode]::Normal) { return processNormalInput $key }
			([AppMode]::Command) { return processCommandInput $key }
			([AppMode]::Error) { return processErrorInput $key }
		}
	}

	function processNormalInput([System.ConsoleKeyInfo]$key) {
		switch ($key.Modifiers) {
			([System.ConsoleModifiers]::Control) {
				switch ($key.Key) {
					'UpArrow' { $itemList.SelectFirst() }
					'DownArrow' { $itemList.SelectLast() }
					'B' { return execGoBackHistory }
					'F' { return execGoForwardHistory }
					'R' {
						$state.ItemListInvalidated = $true
						return [InputResult]::RestartLoop
					}
					'U' { return execMoveToParentDir }
					default { processQueryInput $key }
				}
			}
			([System.ConsoleModifiers]::Alt) {
				switch ($key.Key) {
					'LeftArrow' { return execGoBackHistory }
					'RightArrow' { return execGoForwardHistory }
					'UpArrow' { return execMoveToParentDir }
				}
			}
			default {
				if ($key.KeyChar -eq '/') {
					$state.Mode = [AppMode]::Command
					return [InputResult]::Continue
				}
				switch ($key.Key) {
					'Escape' { return [InputResult]::Exit }
					'Enter' { return execOpenItem }
					'UpArrow' { $itemList.SelectPrev() }
					'DownArrow' { $itemList.SelectNext() }
					'PageUp' { $itemList.SelectPrevPage() }
					'PageDown' { $itemList.SelectNextPage() }
					default { processQueryInput $key }
				}
			}
		}
		return [InputResult]::Continue
	}

	function processCommandInput([System.ConsoleKeyInfo]$key) {
		if ($key.Key -eq [System.ConsoleKey]::Escape) {
			$state.CommandInput.Clear()
			$state.Mode = [AppMode]::Normal
			return [InputResult]::Continue
		}
		if ($key.Key -eq [System.ConsoleKey]::Enter) {
			try {
				$command = parseCommand $state.CommandInput.Text()
				$result = invokeCommand $command
			}
			catch [CommandValidationException] {
				$state.ErrorMessage = $_.Exception.Message
				$state.Mode = [AppMode]::Error
				return [InputResult]::RestartLoop
			}
			if ($result -eq [InputResult]::Exit) {
				return $result
			}
			$state.CommandInput.Clear()
			$state.Mode = [AppMode]::Normal
			return [InputResult]::RestartLoop
		}
		processTextInput $state.CommandInput $key
		return [InputResult]::Continue
	}

	function processErrorInput([System.ConsoleKeyInfo]$key) {
		$state.ErrorMessage = ""
		if ($key.Key -eq [System.ConsoleKey]::Escape) {
			$state.CommandInput.Clear()
			$state.Mode = [AppMode]::Normal
		}
		else {
			$state.Mode = [AppMode]::Command
		}
		return [InputResult]::RestartLoop
	}

	function newCommandValidationError([string]$message) {
		return [CommandValidationException]::new($message)
	}

	function parseCommand([string]$text) {
		$text = $text.Trim()
		if ([string]::IsNullOrEmpty($text)) {
			throw (newCommandValidationError "Command is required")
		}

		$match = [regex]::Match($text, '^(?<name>\S+)(?:\s+(?<argument>.*))?$')
		$name = $match.Groups['name'].Value.ToLowerInvariant()
		$hasArgument = $match.Groups['argument'].Success
		$argument = $match.Groups['argument'].Value.Trim()

		$noArgumentCommands = @('q', 'h', 'help', 'r', 'b', 'f', 'cp', 'd')
		if ($name -in $noArgumentCommands) {
			if ($hasArgument -and -not [string]::IsNullOrWhiteSpace($argument)) {
				throw (newCommandValidationError "/$name does not accept an argument")
			}
			return [PSCustomObject]@{ Name = $name; Destination = $null; Force = $false }
		}

		if ($name -eq 'c' -and -not $hasArgument) {
			return [PSCustomObject]@{ Name = $name; Destination = $null; Force = $false }
		}

		if ($name -notin @('c', 'cf', 'm', 'mf', 'nf', 'nd')) {
			throw (newCommandValidationError "Unknown command: /$name")
		}
		if (-not $hasArgument -or [string]::IsNullOrWhiteSpace($argument)) {
			throw (newCommandValidationError "/$name requires a destination path")
		}

		$singleQuote = [char]39
		$doubleQuote = [char]34
		$first = $argument[0]
		$last = $argument[$argument.Length - 1]
		$firstIsQuote = $first -eq $singleQuote -or $first -eq $doubleQuote
		$lastIsQuote = $last -eq $singleQuote -or $last -eq $doubleQuote
		if ($firstIsQuote -or $lastIsQuote) {
			if (-not ($firstIsQuote -and $last -eq $first -and $argument.Length -ge 2)) {
				throw (newCommandValidationError "Destination path has unmatched quotes")
			}
			$argument = $argument.Substring(1, $argument.Length - 2).Trim()
		}
		if ([string]::IsNullOrWhiteSpace($argument)) {
			throw (newCommandValidationError "/$name requires a destination path")
		}

		try {
			$currentDir = $fs.GetCurrentDir()
			if ($currentDir -eq $fs.SYS_ROOT_PATH) {
				throw [System.ArgumentException]::new("The virtual root cannot resolve a destination")
			}
			$destination = [System.IO.Path]::GetFullPath($argument, $currentDir)
		}
		catch {
			throw (newCommandValidationError "Invalid destination path: $argument")
		}

		return [PSCustomObject]@{
			Name        = $name
			Argument    = $argument
			Destination = $destination
			Force       = $name.EndsWith('f')
		}
	}


	function validateNewItemDestination([string]$destination, [string]$itemName, [string]$commandName) {
		if (
			[System.IO.Path]::IsPathRooted($itemName) -or
			$itemName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
			$itemName.Contains([System.IO.Path]::DirectorySeparatorChar) -or
			$itemName.Contains([System.IO.Path]::AltDirectorySeparatorChar) -or
			$itemName -in @('.', '..')
		) {
			throw (newCommandValidationError "/$commandName accepts a name, not a path")
		}
		$currentDir = $fs.GetCurrentDir()
		$parent = [System.IO.Path]::GetDirectoryName($destination)
		if (-not [string]::Equals($parent, $currentDir, [System.StringComparison]::OrdinalIgnoreCase)) {
			throw (newCommandValidationError "/$commandName accepts a name, not a path")
		}
		if (Test-Path -LiteralPath $destination) {
			throw (newCommandValidationError "Item already exists: $destination")
		}
	}

	function selectedItemPath() {
		$item = $itemList.SelectedItem()
		if ($null -eq $item) {
			throw [System.InvalidOperationException]::new("No item is selected")
		}
		return $item.FullName
	}

	function invokeCommand($command) {
		switch ($command.Name) {
			'q' { return [InputResult]::Exit }
			{ $_ -in @('h', 'help') } {
				Start-Process -FilePath (Join-Path $PSHOME 'pwsh.exe') -ArgumentList @(
					'-NoExit',
					'-File',
					('"{0}"' -f $PSCommandPath),
					'-Help'
				)
			}
			'r' { $state.ItemListInvalidated = $true }
			'b' { return execGoBackHistory }
			'f' { return execGoForwardHistory }
			'cp' { $fs.GetCurrentDir() | Set-Clipboard }
			'd' {
				$fs.DeleteItem((selectedItemPath))
				$state.ItemListInvalidated = $true
			}
			'nf' {
				validateNewItemDestination $command.Destination $command.Argument 'nf'
				$fs.NewFile($command.Destination)
				$state.ItemListInvalidated = $true
			}
			'nd' {
				validateNewItemDestination $command.Destination $command.Argument 'nd'
				$fs.NewDirectory($command.Destination)
				$state.ItemListInvalidated = $true
			}
			'c' {
				$source = selectedItemPath
				if ($null -eq $command.Destination) {
					$source | Set-Clipboard
					break
				}
				$fs.CopyItem($source, $command.Destination, $false)
				$state.ItemListInvalidated = $true
			}
			'cf' {
				$source = selectedItemPath
				$fs.CopyItem($source, $command.Destination, $true)
				$state.ItemListInvalidated = $true
			}
			'm' {
				$source = selectedItemPath
				$fs.MoveItem($source, $command.Destination, $false)
				$state.ItemListInvalidated = $true
			}
			'mf' {
				$source = selectedItemPath
				$fs.MoveItem($source, $command.Destination, $true)
				$state.ItemListInvalidated = $true
			}
		}
		return [InputResult]::Continue
	}

	function execOpenItem() {
		if (-not $itemList.SelectedItem()) {
			return [InputResult]::Continue
		}
		$path = $fs.ResolvePath($itemList.SelectedItem(), $true)

		if ($fs.IsDirectory($path)) {
			$succeeded = $fs.SetCurrentDir($path)
			if ($succeeded) {
				$history.Do($fs.GetCurrentDir())
				$state.QueryInput.Clear()
				$state.ItemListInvalidated = $true
				return [InputResult]::RestartLoop
			}
		}
		else {
			$fs.OpenFile($path)
		}
		return [InputResult]::Continue
	}

	function execMoveToParentDir() {
		$succeeded = $fs.SetCurrentDir("..")
		if ($succeeded) {
			$history.Do($fs.GetCurrentDir())
			$state.QueryInput.Clear()
			$state.ItemListInvalidated = $true
			return [InputResult]::RestartLoop
		}
		return [InputResult]::Continue
	}

	function execGoBackHistory() {
		if ($dirPath = $history.Undo()) {
			$fs.SetCurrentDir($dirPath) | Out-Null
			$state.QueryInput.Clear()
			$state.ItemListInvalidated = $true
			return [InputResult]::RestartLoop
		}
		return [InputResult]::Continue
	}

	function execGoForwardHistory() {
		if ($dirPath = $history.Redo()) {
			$fs.SetCurrentDir($dirPath) | Out-Null
			$state.QueryInput.Clear()
			$state.ItemListInvalidated = $true
			return [InputResult]::RestartLoop
		}
		return [InputResult]::Continue
	}

	$running = $true
	while ($running) {
		updateItemList
		render
		:INPUT_BATCH do {
			$result = processInput $cin.ReadKey() # block if there is no key input.
			switch ($result) {
				([InputResult]::RestartLoop) { break INPUT_BATCH }
				([InputResult]::Exit) {
					$running = $false
					break INPUT_BATCH
				}
			}
		}
		while ($cin.KeyAvailable())
	}
}
finally {
	$cin.Dispose()
	$cout.Dispose()
}
