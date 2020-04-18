  ;-------------------------------------------------------------
	;-- Center and resize a row of buttons automatically
  ;-------------------------------------------------------------
GuiCenterButtons(strWindow, intInsideHorizontalMargin := 10, intInsideVerticalMargin := 0, intDistanceBetweenButtons := 20, arrControls*) {
  ; This is a variadic function. See: http://ahkscript.org/docs/Functions.htm#Variadic
  ; https://autohotkey.com/boards/viewtopic.php?t=3963 from JnLlnd

	DetectHiddenWindows, On
	Gui, Show, Hide
	WinGetPos, , , intWidth, , %strWindow%

	intMaxControlWidth := 0
	intMaxControlHeight := 0
	for intIndex, strControl in arrControls
	{
		GuiControlGet, arrControlPos, Pos, %strControl%
		if (arrControlPosW > intMaxControlWidth)
			intMaxControlWidth := arrControlPosW
		if (arrControlPosH > intMaxControlHeight)
			intMaxControlHeight := arrControlPosH
	}

	intMaxControlWidth := intMaxControlWidth + intInsideHorizontalMargin
	intButtonsWidth := (arrControls.MaxIndex() * intMaxControlWidth) + ((arrControls.MaxIndex()  - 1) * intDistanceBetweenButtons)
	intLeftMargin := (intWidth - intButtonsWidth) // 2

	for intIndex, strControl in arrControls
		GuiControl, Move, %strControl%
			, % "x" . intLeftMargin + ((intIndex - 1) * intMaxControlWidth) + ((intIndex - 1) * intDistanceBetweenButtons)
			. " w" . intMaxControlWidth
			. " h" . intMaxControlHeight + intInsideVerticalMargin
  } ;</06.05.000009>