using module .\mod\file_system.psm1

param (
	[string]$Path = "."
)

# --------------------------------------------------
# preferences
# --------------------------------------------------
$ErrorActionPreference = 'Stop'

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
		ENTER_ALTERNATE_SCREEN_BUF  = [char]0x1B + "[?1049h"
		LEAVE_ALTERNALTE_SCREEN_BUF = [char]0x1B + "[?1049l"
		ERASE_TO_END_OF_LINE        = [char]0x1B + "[K"
		ERASE_TO_END_OF_SCREEN      = [char]0x1B + "[0J"
		SAVE_CURSOR_POS             = [char]0x1B + "7"
		RESTORE_CURSOR_POS          = [char]0x1B + "8"
		MOVE_CURSOR_TO_NEW_LINE     = [char]0x1B + "[1E"
	}
	$prevCursorVisible
	$prevOutputRendering

	ConsoleWriter() {
		$this.prevCursorVisible = [System.Console]::CursorVisible
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
		[System.Console]::TreatControlCAsInput = $this.prevTreatControlCAsInput
		$Global:PSStyle.OutputRendering = $this.prevOutputRendering

		[Console]::Write($this.CMD.LEAVE_ALTERNALTE_SCREEN_BUF)
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
	$inputBox = [InputBox]::new()
	$itemList = [ListViewer]::new()

	$Path = $fs.ResolvePath($Path, $true)
	if ($fs.IsDirectory($Path)) {
		$fs.SetCurrentDir($Path) | Out-Null
	}
	else {
		$fs.SetCurrentDir(($Path | Split-Path -Parent)) | Out-Null
		$inputBox.InsertString(($Path | Split-Path -Leaf))
	}
	$history.Do($fs.GetCurrentDir())

	function updateItemList() {
		$query = $inputBox.Text()
		$currentDir = $fs.GetCurrentDir()

		# detect status change
		if (
			$Script:lastQuery -eq $query -and
			$Script:lastCurrentDir -eq $currentDir -and
			-not $Script:reloadRequired
		) {
			return
		}
		$Script:lastQuery = $query
		$Script:lastCurrentDir = $currentDir
		$Script:reloadRequired = $false

		$itemList.SetItems($fs.GetChildItems($query))
	}

	function render() {
		$cout.HideCursor()
		$cout.SetCursorPosition(0, 0)

		# render current dir
		$cout.PrintLn($PSStyle.Foreground.Cyan + $fs.GetDisplayCurrentDir() + $Global:PSStyle.Reset)

		# render input box
		$cout.Print("? " + $inputBox.TextBeforeCursor())
		$desiredCursorPosition = $cout.CursorPosition()
		$cout.PrintLn($inputBox.TextAfterCursor())

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

		$cout.SetCursorPosition($desiredCursorPosition)
		$cout.ShowCursor()
	}

	function procInput([System.ConsoleKeyInfo]$key) {
		switch ($key.Modifiers) {
			([System.ConsoleModifiers]::Control) {
				switch ($key.Key) {
					'LeftArrow' { $inputBox.MoveCursorToLeftEnd() }
					'RightArrow' { $inputBox.MoveCursorToRightEnd() }
					'UpArrow' { $itemList.SelectFirst() }
					'DownArrow' { $itemList.SelectLast() }
					'Backspace' { $inputBox.TruncateLeft() }
					'Delete' { $inputBox.TruncateRight() }
					'B' { execGoBackHistory }
					'C' { $itemList.SelectedItem().FullName | Set-Clipboard }
					'F' { execGoForwardHistory }
					'R' { $Script:reloadRequired = $true }
					'U' { execMoveToParentDir }
					'V' { $inputBox.InsertString((Get-Clipboard)) }
				}
			}
			([System.ConsoleModifiers]::Control -bor [System.ConsoleModifiers]::Shift) {
				switch ($key.Key) {
					'C' { $fs.GetCurrentDir() | Set-Clipboard }
				}
			}
			([System.ConsoleModifiers]::Alt) {
				switch ($key.Key) {
					'LeftArrow' { execGoBackHistory }
					'RightArrow' { execGoForwardHistory }
					'UpArrow' { execMoveToParentDir }
				}
			}
			default {
				switch ($key.Key) {
					'Escape' { exit }
					'Enter' { execOpenItem }
					'LeftArrow' { $inputBox.MoveCursorLeft() }
					'RightArrow' { $inputBox.MoveCursorRight() }
					'UpArrow' { $itemList.SelectPrev() }
					'DownArrow' { $itemList.SelectNext() }
					'Home' { $inputBox.MoveCursorToLeftEnd() }
					'End' { $inputBox.MoveCursorToRightEnd() }
					'PageUp' { $itemList.SelectPrevPage() }
					'PageDown' { $itemList.SelectNextPage() }
					'Backspace' { $inputBox.DeleteLeft() }
					'Delete' { $inputBox.DeleteRight() }
					default { $inputBox.InsertChar($key.keyChar) }
				}
			}
		}
	}

	function execOpenItem() {
		if (-not $itemList.SelectedItem()) {
			return
		}
		$path = $fs.ResolvePath($itemList.SelectedItem(), $true)

		if ($fs.IsDirectory($path)) {
			$succeeded = $fs.SetCurrentDir($path)
			if ($succeeded) {
				$history.Do($fs.GetCurrentDir())
				$inputBox.Clear()
				break INPUT_LOOP
			}
		}
		else {
			$fs.OpenFile($path)
		}
	}

	function execMoveToParentDir() {
		$succeeded = $fs.SetCurrentDir("..")
		if ($succeeded) {
			$history.Do($fs.GetCurrentDir())
			$inputBox.Clear()
			break INPUT_LOOP
		}
	}

	function execGoBackHistory() {
		if ($dirPath = $history.Undo()) {
			$fs.SetCurrentDir($dirPath) | Out-Null
			$inputBox.Clear()
			break INPUT_LOOP
		}
	}

	function execGoForwardHistory() {
		if ($dirPath = $history.Redo()) {
			$fs.SetCurrentDir($dirPath) | Out-Null
			$inputBox.Clear()
			break INPUT_LOOP
		}
	}

	while ($true) {
		updateItemList
		render $inputBox $itemList
		:INPUT_LOOP do {
			procInput $cin.ReadKey()
		}
		while ($cin.KeyAvailable())
	}
}
finally {
	$cin.Dispose()
	$cout.Dispose()
}
