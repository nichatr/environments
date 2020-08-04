; script directives
  #SingleInstance, Force
  #NoEnv
  SetWorkingDir %A_ScriptDir%
  SetBatchLines -1
  SendMode Input ; Forces Send and SendRaw to use SendInput buffering for speed.
  SetTitleMatchMode, 3 ; A window's title must exactly match WinTitle to be a match.
  SplitPath, A_ScriptName, , , , thisscriptname
  #MaxThreadsPerHotkey, 1 ; no re-entrant hotkey handling
  ; DetectHiddenWindows, On
  ; SetWinDelay, -1 ; Remove short delay done automatically after every windowing command except IfWinActive and IfWinExist
  ; SetKeyDelay, -1, -1 ; Remove short delay done automatically after every keystroke sent by Send or ControlSend
  ; SetMouseDelay, -1 ; Remove short delay done automatically after Click and MouseMove/Click/Drag


; global declarations
  Global MyTreeView, EnvironmentListView, TreeViewWidth, ListViewWidth
  Global RunButton, NewButton, EditButton, DeleteButton, RefreshButton, CloseButton
  Global myshortcutName, myShortcutTarget, myEnvDescription, oldShortcutName
  Global SaveEnvironmentButton, CancelEnvironmentButton
  Global myApplicationDropdownList, SelectFileButton, SaveShortcutButton, CancelShortcutButton, myEnvName
  Global AllEnvironmentsFolder, selectedEnvironment, selectedSubpath, selectedDescription, selectedApp
  Global GuiX, GuiY, GuiW, GuiH ; for positioning of main gui and msgboxes
  Global mainGui_title, subGui_title
  Global subGui3_X, subGui3_Y, subGui3_W, subGui3_H
  Global subGui4_X, subGui4_Y, subGui4_W, subGui4_H
  Global gui2Hwnd, gui3Hwnd, gui4Hwnd
  Global MyTreeViewHwnd, EnvironmentListViewHwnd
  Global OK_MESSAGE, YES_NO_DANGER_MESSAGE
  Global lastClicked
  Global Applications, environmentDescription
  Global INI_file
  Global ImageListID1, ImageListID2

setupEnvironments()
  return
  ;---------------------------------------------------------------------
  ; setup initial values
  ;---------------------------------------------------------------------
setupEnvironments() {

  menu, tray, icon, %A_ScriptDir%/icons/development.png

  ; for drop down list.
  Applications := "Select application|URL|VSCode|Notepad++|Word|Excel|Link|Pdf"
  ; for message repositioning.
  OK_MESSAGE := 4096
  YES_NO_DANGER_MESSAGE := 0x40114

  ; create (when doesn't exist) the main folder which keeps all environments
  AllEnvironmentsFolder := A_ScriptDir . "\environments"

  if (!FileExist(AllEnvironmentsFolder))
    FileCreateDir, %AllEnvironmentsFolder%

  ; create INI file if it doesn't exist
  INI_file := "environments.ini"
  if (!FileExist(INI_file)) {
    IniWrite, -7, %INI_file%, position, winX
    IniWrite, 500, %INI_file%, position, winY
    IniWrite, 1400, %INI_file%, position, winWidth
    IniWrite, 400, %INI_file%, position, winHeight
    IniWrite, true, %INI_file%, general, saveOnExit
    IniWrite, c:\, %INI_file%, general, lastFolderSelection
    }
  IniRead, GuiX, %INI_file%, position, winX
  IniRead, GuiY, %INI_file%, position, winY
  IniRead, GuiW, %INI_file%, position, winWidth
  IniRead, GuiH, %INI_file%, position, winHeight

  getMonitorsSizes(minLeft, maxRight, maxBottom)
  adjustGui_SizePosition(GuiX, GuiY, GuiW, GuiH, minLeft, maxRight, maxBottom)
  
  ; initialize with default values if any value is null
  if (GuiX = "" or GuiY = "" or GuiW = "" or GuiH = "") {
    GuiX := -7
    GuiY := 500
    GuiW := 1400
    GuiH := 400
    }

  TreeViewWidth := 280
  ListViewWidth := GuiW - TreeViewWidth - 30
  
  IniRead, fontSize, %INI_file%, general, fontSize
  mainGui_title := A_ScriptName
  Gui, 2:New, +Resize +Hwndgui2Hwnd, %mainGui_title%
  Gui, 2:Font, s%fontSize%
  Gui, %gui2Hwnd%:Default

  ; Create an ImageList and put some standard system icons into it:
  ImageListID3 := IL_Create(5)
  Loop 5 
    IL_Add(ImageListID3, "shell32.dll", A_Index)
  
  ; Create a TreeView and a ListView side-by-side to behave like Windows Explorer:
  Gui, 2:Add, TreeView, vMyTreeView gMyTreeView_Events +HwndMyTreeViewHwnd +AltSubmit r20 w%TreeViewWidth% ImageList%ImageListID3%
  Gui, 2:Add, ListView, vEnvironmentListView gEnvironmentListView_Events +HwndEnvironmentListViewHwnd +AltSubmit r20 w%ListViewWidth% x+10 , Shortcut|App|Target|Args
  
  newButton_y := 0 ; 313 + 33
  Gui, 2:Add, Button, x24 y%newButton_y% w80 h23 vRunButton gRunButton +HwndRunButtonHwnd, Run
  Gui, 2:Add, Button, xp+88 y%newButton_y% w80 h23 vNewButton gNewButton, New
  Gui, 2:Add, Button, xp+88 y%newButton_y% w80 h23 vEditButton gEditButton, Edit
  Gui, 2:Add, Button, xp+88 y%newButton_y% w80 h23 vDeleteButton gDeleteButton, Delete
  Gui, 2:Add, Button, xp+88 y%newButton_y% w80 h23 vRefreshButton gRefreshButton, Refresh
  Gui, 2:Add, Button, xp+88 y%newButton_y% w80 h23 vCloseButton gCloseButton Default, Close
  GuiCenterButtons(mainGui_title, 10, 2, 3, "RunButton", "NewButton", "EditButton", "DeleteButton", "RefreshButton", "CloseButton")

  Menu, environmentContextMenu, Add, &Run all environment's shortcuts, contextMenuHandler
  Menu, environmentContextMenu, Add, &Edit environment, contextMenuHandler
  Menu, environmentContextMenu, Add, &Delete environment, contextMenuHandler

  Menu, shortcutContextMenu, Add, &Run shortcut, contextMenuHandler
  Menu, shortcutContextMenu, Add, &Edit shortcut, contextMenuHandler
  Menu, shortcutContextMenu, Add, &Delete shortcut, contextMenuHandler

  ; Add folders and their subfolders to the tree. Display the status in case loading takes a long time:
  SplashTextOn, 200, 25, TreeView and StatusBar Example, Loading the tree...
  AddSubFoldersToTree(AllEnvironmentsFolder)
  SplashTextOff

  loadSubGuis()

  OnMessage(0x200, "Help")  ; to show descriptions as tooltips on environments treeview.

  Gui, 2:+E0x10

  ; Display the window and return. The OS will notify the script whenever the user performs an eligible action:
  Gui, 2:Show, W%GuiW% H%GuiH% x%GuiX% y%GuiY%, %AllEnvironmentsFolder%  ; Display the source directory (AllEnvironmentsFolder) in the title bar.
  lastClicked := MyTreeViewHwnd ; mark treeview as clicked, otherwise no selected list exists!
  return
  }
  ;---------------------------------------------------------------------
  ; show tooltips on certain controls
  ;---------------------------------------------------------------------
Help() {
  MouseGetPos,,,, OutputVarControl, 2  ; 2=Stores the control's HWND

  if (OutputVarControl = MyTreeViewHwnd and environmentDescription <> "ERROR") {

    myTooltip := environmentDescription
    }
  else 
    myTooltip := ""

  ToolTip % myTooltip
  }
  ;---------------------------------------------------------------------
  ; setup the sub guis
  ;---------------------------------------------------------------------
loadSubGuis() {
  ;-----------------------------------------
  ; initialize secondary <shortcut> gui
  ;-----------------------------------------
  subGui3_W := 750
  subGui3_H := 270
  subGui_title := "Manage shortcut"

  Gui, 3:Destroy
  Gui, 3:New, -Caption +Hwndgui3Hwnd, %subGui_title%
  Gui, 3:Font, s%fontSize%
  Gui, 3:+Owner

  Gui, 3:Add, GroupBox, xm+5 y+10 w700 h250, Manage shortcut

  Gui, 3:Add, Text, x40 y50 w80 h23 +0x200 Section, Environment
  Gui, 3:Add, Text, xp+200 yp+5 w345 h23 vmyEnvName , TEST

  Gui, 3:Add, Text, x40 yp+25 w180 h23 +0x200, Open Shortcut with Application
  newList := StrReplace(Applications, "Select application", "Select application|")
  Gui, 3:Add, DropDownList, xp+200 yp w201 vmyApplicationDropdownList gmyApplicationDropdownList, %newList%

  Gui, 3:Add, Text, x40 yp+30 w100 h23 +0x200, Shortcut Name
  Gui, 3:Add, Edit, xp+200 yp w345 h21 vmyshortcutName

  Gui, 3:Add, Text, x40 yp+30 w160 h23 +0x200, Select Shortcut Link Target
  Gui, 3:Add, Edit, xp+200 yp w345 h21 r3 vmyShortcutTarget

  Gui, 3:Add, Button, xp+360 yp w80 h23 vSelectFileButton gSelectFileButton, File

  Gui, 3:Add, Button, x250 yp+65 w80 h23 vSaveShortcutButton gSaveShortcutButton Default, Save
  Gui, 3:Add, Button, x350 yp w80 h23 vCancelShortcutButton gCancelShortcutButton, Cancel
  ;-----------------------------------------
  ; initialize secondary <environment> gui
  ;-----------------------------------------
  subGui4_W := 700
  subGui4_H := 180
  subGui_title := "Manage environment"

  Gui, 4:Destroy
  Gui, 4:New, -Caption +Hwndgui4Hwnd, %subGui_title%
  Gui, 4:Font, s%fontSize%
  Gui, 4:+Owner

  Gui, 4:Add, GroupBox, xm+5 y+10 w650 h250, Manage environment

  Gui, 4:Add, Text, x40 y50 w80 h23 +0x200 Section, Environment
  Gui, 4:Add, Edit, x120 yp w450 h23 vmyEnvName
  
  Gui, 4:Add, Text, x40 yp+30 w80 h23 +0x200 Section, Description
  Gui, 4:Add, Edit, x120 yp w450 h23 vmyEnvDescription
  
  Gui, 4:Add, Button, x250 yp+40 w80 h23 vSaveEnvironmentButton gSaveEnvironmentButton Default, Save
  Gui, 4:Add, Button, x350 yp w80 h23 vCancelEnvironmentButton gCancelEnvironmentButton, Cancel
  }
  ;-------------------------------------------------  
  ; events for treeview (environments).
  ;-------------------------------------------------
MyTreeView_Events(CtrlHwnd:=0, GuiEvent:="", EventInfo:="", ErrLvl:="")
  {
    if (A_GuiEvent = "DoubleClick") {
      RunEnvironment()
      Return
      }

    if (A_GuiEvent != "Normal")  ; left click a row
      return  ; Do nothing.
    
    ; keep treeview as last clicked control
    lastClicked := MyTreeViewHwnd

    loadShortcuts(A_EventInfo)
  }
  ;-------------------------------------------------  
  ; events for listview (shortcuts).
  ;-------------------------------------------------
EnvironmentListView_Events(CtrlHwnd:=0, GuiEvent:="", EventInfo:="", ErrLvl:="")
  {
    if (A_GuiEvent = "DoubleClick") {
      RunShortcut()
      Return
      }
    
    if (A_GuiEvent = "K") { ; pressed a key
      keypressed := GetKeyName(Format("vk{:x}", A_EventInfo))
      if (keypressed = "NumpadDel")
        DeleteShortcut()
      Return
      }

    if (A_GuiEvent != "Normal") ; left click a row
      return  ; Do nothing.

    ; keep treeview as last clicked control
    lastClicked := EnvironmentListViewHwnd
  }
  ;-------------------------------------------------
  ; run button handler
  ;-------------------------------------------------
RunButton(CtrlHwnd:=0, GuiEvent:="", EventInfo:="", ErrLvl:="") {

  if (lastClicked = MyTreeViewHwnd)
    RunEnvironment()
  
  if (lastClicked = EnvironmentListViewHwnd)
    RunShortcut()

  }
  ;-------------------------------------------------
  ; new button handler
  ;-------------------------------------------------
NewButton(CtrlHwnd:=0, GuiEvent:="", EventInfo:="", ErrLvl:="") {

  if (lastClicked = MyTreeViewHwnd)
    NewEnvironment()
  
  if (lastClicked = EnvironmentListViewHwnd)
    NewShortcut()

  }
  ;-------------------------------------------------
  ; edit button handler
  ;-------------------------------------------------
EditButton(CtrlHwnd:=0, GuiEvent:="", EventInfo:="", ErrLvl:="") {

  if (lastClicked = MyTreeViewHwnd) {
    EditEnvironment()
  }
  
  if (lastClicked = EnvironmentListViewHwnd) {
    EditShortcut()
  }

  }
  ;-------------------------------------------------
  ; delete button handler
  ;-------------------------------------------------
DeleteButton(CtrlHwnd:=0, GuiEvent:="", EventInfo:="", ErrLvl:="") {

  if (lastClicked = MyTreeViewHwnd) {
    DeleteEnvironment()
  }
  
  if (lastClicked = EnvironmentListViewHwnd) {
    DeleteShortcut()
  }

  }
  ;-------------------------------------------------
  ; refresh button handler
  ;-------------------------------------------------
RefreshButton(CtrlHwnd:=0, GuiEvent:="", EventInfo:="", ErrLvl:="") {

  if (lastClicked = MyTreeViewHwnd) {
    RefreshEnvironment()
  }
  
  if (lastClicked = EnvironmentListViewHwnd) {
    RefreshShortcuts()
  }

  }
  ;---------------------------------------------------------------------
  ; Expand/shrink the tab in response to user's resizing of window.
  ;---------------------------------------------------------------------
2GuiSize:
  {
    if (A_EventInfo = 1)  ; The window has been minimized. No action needed.
      return

    Gui, 2:Default
    ; Gui, 2:-Disabled
    
    GuiH := A_GuiHeight
    GuiW := A_GuiWidth

    ; resize treeview and listview.
    GuiControl, 2:Move, MyTreeView, % "H" . (A_GuiHeight - 30 - 10)  ; -30 for StatusBar and margins.
    GuiControl, 2:Move, EnvironmentListView, % "H" . (A_GuiHeight - 30 - 10) . " W" . (A_GuiWidth - TreeViewWidth - 30)

    ; reposition buttons
    GuiControlGet, MyTreeView, 2:Pos
    newButton_y := MyTreeViewH + 10
    GuiControl, 2:Move, RunButton, y%newButton_y%
    GuiControl, 2:Move, NewButton, y%newButton_y%
    GuiControl, 2:Move, EditButton, y%newButton_y%
    GuiControl, 2:Move, DeleteButton, y%newButton_y%
    GuiControl, 2:Move, RefreshButton, y%newButton_y%
    GuiControl, 2:Move, CloseButton, y%newButton_y%

    return
  }

 ; Exit the script when the user closes the TreeView's GUI window.
2Escape:
2GuiEscape:
2GuiClose:
CloseButton:
  saveEnvironmentSettings()
  Gui, 2:Destroy
  Gui, 3:Destroy
  Gui, 4:Destroy
  Return
  ;----------------------------------------------------------------
  ; drag & drop action on shortcuts: add files/folders as links.
  ;----------------------------------------------------------------
2GuiDropFiles(GuiHwnd, FileArray, CtrlHwnd, X, Y) {

  getSelectedEnvironment()
  if (selectedEnvironment = "")
    Return
    
  for i, file in FileArray
    {
      SplitPath, file, FileName, Dir, Extension, NameNoExt, Drive
      if (createShortcutFile("Link", NameNoExt, file))
        refreshShortcuts()
        ; MsgBox Environment= %selectedEnvironment% File %i% is:`n%file%
    }
  }
  ;----------------------------------------------------------------
  ; Launched in response to a right-click or press of the Apps key.
  ;----------------------------------------------------------------
2GuiContextMenu(GuiHwnd, CtrlHwnd, EventInfo, IsRightClick, X, Y)
  {
  ; Show the menu at the provided coordinates, A_GuiX and A_GuiY. These should be used
  ; because they provide correct coordinates even if the user pressed the Apps key:

  if (A_GuiControl = "MyTreeView") {
	  Menu, environmentContextMenu, Show, %A_GuiX%, %A_GuiY%
    }
  if (A_GuiControl = "EnvironmentListView") {
	  Menu, shortcutContextMenu, Show, %A_GuiX%, %A_GuiY%
    }

  Return
  }
  ;-----------------------------------------------------------
  ; Handle context menu actions
  ;-----------------------------------------------------------
contextMenuHandler:
  {
    
  if (A_ThisMenuItem = "&Run all environment's shortcuts")
    RunEnvironment()

  if (A_ThisMenuItem = "&Edit environment")
    EditEnvironment()

  if (A_ThisMenuItem = "&Delete environment")
    DeleteEnvironment()

  if (A_ThisMenuItem = "&Run shortcut")
    RunShortcut()

  if (A_ThisMenuItem = "&Edit shortcut")
    EditShortcut()

  if (A_ThisMenuItem = "&Delete shortcut")
    DeleteShortcut()

  Return
  }
 ;---------------------------------------------------------------------
  ; save settings to ini  
  ;---------------------------------------------------------------------
saveEnvironmentSettings() {
  ; actWin := WinExist("A")
  ; actWin := WinExist("ahk_id" . %gui2Hwnd%)
  ; WinGet, isMinimized , MinMax, actWin
  WinGet, isMinimized , MinMax, ahk_id %gui2Hwnd%
  IniRead, saveOnExit, %INI_file%, general, saveOnExit

  ; on exit save position & size of window
  ; but if it is minimized skip this step.
  if (isMinimized = -1 or saveOnExit != "true")
    Return

  getMonitorsSizes(minLeft, maxRight, maxBottom)
  WinGetPos, winX, winY, winWidth, winHeight, ahk_id %gui2Hwnd%
  adjustGui_SizePosition(winX, winY, winWidth, winHeight, minLeft, maxRight, maxBottom)

  ; save X, Y that are absolute values.
  IniWrite, %winX%, %INI_file%, position, winX
  IniWrite, %winY%, %INI_file%, position, winY

  getClientSize(actWin, winWidth, winHeight)

  if (winWidth > 0)
    IniWrite, %winWidth%, %INI_file%, position, winWidth
  if (winHeight > 0)
    IniWrite, %winHeight%, %INI_file%, position, winHeight

  ; timestamp
  FormatTime, currentTimestamp,, yyyy-MM-dd hh:mm:ss
  FileEncoding, CP1253 
  IniWrite, %currentTimestamp%, %INI_file%, general, lastSavedTimestamp
  }
  ;-------------------------------------------------
  ; find number of monitors and their sizes
  ; keep min left, max right, max bottom
  ;-------------------------------------------------
getMonitorsSizes(Byref minLeft := 0, ByRef maxRight := 0, ByRef maxBottom := 0) {
  minLeft := 0
  maxRight := 0
  maxBottom := 0
  sysget, monitorCount, MonitorCount
  Loop, %monitorCount%
    {
      SysGet, Mon%A_Index%, Monitor, %A_Index%
      if (Mon%A_Index%Left < minLeft)
        minLeft := Mon%A_Index%Left
      if (Mon%A_Index%Right > maxRight)
        maxRight := Mon%A_Index%Right
      if (Mon%A_Index%Bottom > maxBottom)
        maxBottom := Mon%A_Index%Bottom
    }
  }
  ;---------------------------------------------------------------------
  ; adjust gui size and position to real display(s)
  ;---------------------------------------------------------------------
adjustGui_SizePosition(Byref winX, Byref winY, Byref winWidth, Byref winHeight, Byref minLeft, Byref maxRight, Byref maxBottom) {
  
  ; if left, right, bottom are beyond boundaries adjust them.
  if (winX < minLeft - 7)
    winX := minLeft - 7
  if (winX > maxRight - winWidth)
    winX := maxRight - winWidth
  if (winY > maxBottom - winHeight - 30)
    winY := maxBottom - winHeight - 30

  }
  ;---------------------------------------------------------------------
  ; get actual gui size 
  ;---------------------------------------------------------------------
getClientSize(hWnd, ByRef w := "", ByRef h := "") {
    VarSetCapacity(rect, 16)
    DllCall("GetClientRect", "ptr", hWnd, "ptr", &rect)
    w := NumGet(rect, 8, "int")
    h := NumGet(rect, 12, "int")
  }
  ;-------------------------------------------------
  ; save environment button handler
  ;-------------------------------------------------
SaveEnvironmentButton(CtrlHwnd:=0, GuiEvent:="", EventInfo:="", ErrLvl:="") {

  Gui, 4:Submit, NoHide ; save user input to corresponding variables

  GuiControlGet, myEnvName, , myEnvName ; get environment name
  myEnvName := Trim(MyEnvname)
  if (myEnvName = "") {
    ShowMsgbox(OK_MESSAGE, "Warning", "Environment name must be non blank")
    Return
    }

  newFile := AllEnvironmentsFolder . "\" . myEnvName
  if (FileExist(newFile) and selectedEnvironment = "") {
    ShowMsgbox(OK_MESSAGE, "Warning", "Environment already exists")
    Return
  }

  if (selectedEnvironment = "") {
    FileCreateDir, %AllEnvironmentsFolder%\%myEnvName%  ; create new environment (as a folder)
    updateDescription()
  }
  else if (myEnvName = selectedEnvironment) {   ; update just the description
    updateDescription()
  } else if (FileExist(newFile)) {
    ShowMsgbox(OK_MESSAGE, "Warning", "New environment name already exists")
    Return
  } else {  ; environment was renamed: rename folder
    FileMoveDir, %AllEnvironmentsFolder%\%selectedEnvironment%, %AllEnvironmentsFolder%\%myEnvName%, R  ; R=rename
    renameDescription()
  }

  Gui, 2:-Disabled
  Gui, 4:Hide
  refreshEnvironments()
  }
  ;-------------------------------------------------
  ; update selected environment description in INI
  ;------------------------------------------------
updateDescription() {
  IniWrite, %myEnvDescription%, %A_ScriptDir%\%INI_file%, %myEnvName%, description
  if (ErrorLevel = 1) {
    msgbox, % error
    }
  ; timestamp
  FormatTime, currentTimestamp,, yyyy-MM-dd hh:mm:ss
  IniWrite, %currentTimestamp%, %A_ScriptDir%\%INI_file%, %myEnvName%, lastSavedTimestamp
  }
  ;---------------------------------------------------
  ; delete old and write new environment (on renaming)
  ;---------------------------------------------------
renameDescription() {
  IniDelete, %A_ScriptDir%\%INI_file%, %selectedEnvironment%
  updateDescription()
  }
  ;-------------------------------------------------
  ; cancel save environment button handler
  ;-------------------------------------------------
CancelEnvironmentButton(CtrlHwnd:=0, GuiEvent:="", EventInfo:="", ErrLvl:="") {

  Gui, 4:Hide
  Gui, 2:-Disabled
  Gui, 2:Show
  }
  
4GuiEscape:
4GuiClose:
  CancelEnvironmentButton()
  Return
  ;------------------------------------------------------------------------------
  ; it is executed when selecting a new item from the applications dropdown list.
  ;------------------------------------------------------------------------------
myApplicationDropdownList(CtrlHwnd:=0, GuiEvent:="", EventInfo:="", ErrLvl:="") {
  Return
  }
  ;-------------------------------------------------
  ; save shortcut button handler
  ;-------------------------------------------------
SaveShortcutButton(CtrlHwnd:=0, GuiEvent:="", EventInfo:="", ErrLvl:="") {
  
  Gui, 3:Submit, NoHide ; save user input to corresponding variables

  GuiControlGet, selectedEnv, , myEnvName ; get selected environment
  if (selectedEnv = "" or selectedEnv = "Select environment") {
    ShowMsgbox(OK_MESSAGE, "Warning", "Select an Environment first")
    Return
    }

  if (isEmptyApplication())
    Return

  if (myshortcutName = "" or myShortcutTarget = "") {
    ShowMsgbox(OK_MESSAGE, "Warning", "Complete Shortcut Name and File/Folder")
    Return
    }

  if (!createShortcutFile(selectedApp, myshortcutName, myShortcutTarget))
    Return
    
  Gui, 2:-Disabled
  Gui, 3:Hide
  refreshShortcuts()
  }
  ;-------------------------------------------------
  ; cancel save shortcut button handler
  ;-------------------------------------------------
CancelShortcutButton(CtrlHwnd:=0, GuiEvent:="", EventInfo:="", ErrLvl:="") {
  
  Gui, 3:Hide
  Gui, 2:-Disabled
  Gui, 2:Show
  }

3GuiEscape:
3GuiClose:
  CancelShortcutButton()
  Return
  ;----------------------------------------------
  ; it is executed when file button is pressed.
  ;----------------------------------------------
SelectFileButton(CtrlHwnd:=0, GuiEvent:="", EventInfo:="", ErrLvl:="") {
  
  if (isEmptyApplication())
    Return

  filter := getFileFilter()

  selectedFile := fileFolderSelector(filter)
  if (selectedFile = "")
    Return

  ; this is the way to change a control in another Gui.
  GuiControl, 3:, myShortcutTarget, %selectedFile%
  }
  ;-------------------------------------------------
  ; run environment handler
  ;-------------------------------------------------
RunEnvironment() {

  getSelectedEnvironment()
  if (selectedEnvironment = "")
    Return

  errorList := ""

  ; run all environment's shortcuts
  Loop, Files, %A_ScriptDir%\environments\%selectedSubpath%\*.*   ; means include only files
  {
    Run, %A_LoopFileFullPath%, UseErrorLevel
    if (ErrorLevel)
      errorList .= "`n" . A_LoopFileName . "`terrorlevel=" . ErrorLevel
  }

  if (errorList <> "")
    ShowMsgbox(OK_MESSAGE, "Warning", "Could not run the shortcut(s) " . errorList)
  }
  ;-------------------------------------------------
  ; new environment handler
  ;-------------------------------------------------
NewEnvironment() {

  selectedEnvironment := ""
  myEnvName := ""
  myEnvDescription := ""
  GuiControl, 4:, myEnvName,  ; update the env.name
  GuiControl, 4:, myEnvDescription,  ; update the description

  showSubgui4()
  }
  ;-------------------------------------------------
  ; edit environment handler
  ;-------------------------------------------------
EditEnvironment() {

  getSelectedEnvironment()
  if (selectedEnvironment = "")
    Return  
  
  GuiControl, 4:, myEnvName, %selectedEnvironment%  ; update the env.name
  GuiControl, 4:, myEnvDescription, %environmentDescription%  ; update the env.description
  showSubgui4()
  }
  ;-------------------------------------------------
  ; delete environment handler
  ;-------------------------------------------------
DeleteEnvironment() {

  getSelectedEnvironment()
  if (selectedEnvironment = "")
    Return
  
  ShowMsgbox(YES_NO_DANGER_MESSAGE, "Warning", "Delete Environment?")
  IfMsgBox, Yes
  {
    FileSetAttrib, -R, %AllEnvironmentsFolder%\%selectedSubpath%
    FileRemoveDir, %AllEnvironmentsFolder%\%selectedSubpath%
    If (ErrorLevel = 0) {
      ShowMsgbox(OK_MESSAGE, "Info", "Environment deleted")
      refreshEnvironments()
      } else
    msgbox, Cannot delete folder

  }

  }
  ;-------------------------------------------------
  ; refresh environment handler
  ;-------------------------------------------------
RefreshEnvironment() {
  refreshEnvironments()
  }
  ;---------------------------------------------------------------------
  ; return selected environment
  ;---------------------------------------------------------------------
getSelectedEnvironment() {

  Gui, 2:Default
  
  parentID := TV_GetSelection()   ; get selected ID
  TV_GetText(selectedEnvironment, parentID)   ; get selected item text
  if (selectedEnvironment = "") {
    ShowMsgbox(OK_MESSAGE, "Warning", "Select an environment")
    Return
    }

  ; if folder is nested get the full path upwards up to base folder (environments\)
  selectedSubpath := selectedEnvironment

  Loop  ; Build the full path to the selected folder.
  {
    ParentID := TV_GetParent(ParentID)
    if not ParentID  ; No more ancestors.
        break
    TV_GetText(ParentText, ParentID)
    selectedSubpath := ParentText "\" selectedSubpath
  }
  }
  ;-------------------------------------------------
  ; reload treeview with environments
  ;------------------------------------------------
refreshEnvironments() {
  Gui, 2:Default
  GuiControl, -Redraw, MyTreeView
  TV_Delete() ; clear all environments
  LV_Delete()  ; Clear all shortcut rows.
  AddSubFoldersToTree(AllEnvironmentsFolder)
  GuiControl, +Redraw, MyTreeView
  }
  ;-------------------------------------------------
  ; run shortcut handler
  ;-------------------------------------------------
RunShortcut() {

  getSelectedEnvironment()
  if (selectedEnvironment = "")
    Return

  selectedRow := LV_GetNext()
  if (selectedRow = 0) {
    ShowMsgbox(OK_MESSAGE, "Warning", "Select a shortcut")
    Return
    }

  LV_GetText(shortcutFile, selectedRow, 1)

  Run, %A_ScriptDir%\environments\%selectedSubpath%\%shortcutFile%,, UseErrorLevel
  if (ErrorLevel <> 0)
    ShowMsgbox(OK_MESSAGE, "Warning", "Could not run shortcut")
  }
  ;-------------------------------------------------
  ; new shortcut handler
  ;-------------------------------------------------
NewShortcut() {

  getSelectedEnvironment()
  if (selectedEnvironment = "")
    Return

  initializeGui3()
  showSubgui3()
  }
  ;-------------------------------------------------
  ; edit shortcut handler
  ;-------------------------------------------------
EditShortcut() {

  getSelectedEnvironment()
  if (selectedEnvironment = "")
    Return

  selectedRow := LV_GetNext()
  if (selectedRow = 0) {
    ShowMsgbox(OK_MESSAGE, "Warning", "Select a shortcut")
    Return
    }
  
  loadGui3(selectedRow)
  showSubgui3()
  }
  ;-------------------------------------------------
  ; delete shortcut handler
  ;-------------------------------------------------
DeleteShortcut() {

  getSelectedEnvironment()
  if (selectedEnvironment = "")
    Return

  selectedRow := LV_GetNext()
  if (selectedRow = 0) {
    ShowMsgbox(OK_MESSAGE, "Warning", "Select a shortcut")
    Return
    }
  
  ShowMsgbox(YES_NO_DANGER_MESSAGE, "Warning", "Delete shortcut?")
  IfMsgBox, Yes
  {
    LV_GetText(shortcutName, selectedRow, 1)
    FileDelete, %AllEnvironmentsFolder%\%selectedSubpath%\%shortcutName%
    refreshShortcuts()
  }
  }
  ;-------------------------------------------------
  ; reload listview with shortcuts
  ;------------------------------------------------
refreshShortcuts() {

  Gui, 2:Default
  selectedID := TV_GetSelection()
  loadShortcuts(selectedID)
  }
  ;-------------------------------------------------
  ; reload listview with shortcuts
  ;------------------------------------------------
loadShortcuts(selectedID) {
  ;
  ; logic for populating the Listview with icons is taken from:
  ;     https://www.autohotkey.com/docs/commands/ListView.htm#ExAdvanced
  ;
  TV_GetText(selectedEnvironment, selectedID)
  if (selectedEnvironment = "")
    Return

  IniRead, environmentDescription, %A_ScriptDir%\%INI_file%, %selectedEnvironment%, description
  ParentID := selectedID
  selectedSubpath := selectedEnvironment

  Loop  ; Build the full path to the selected folder.
  {
    ParentID := TV_GetParent(ParentID)
    if not ParentID  ; No more ancestors.
        break
    TV_GetText(ParentText, ParentID)
    selectedSubpath := ParentText "\" selectedSubpath
  }
  SelectedFullPath := AllEnvironmentsFolder "\" selectedSubpath

  LV_Delete()  ; Clear all rows.
  IL_Destroy(ImageListID1)  ; small shortcuts icons
  IL_Destroy(ImageListID2)  ; big shortcuts icons
  ImageListID1 := IL_Create(10)
  ImageListID2 := IL_Create(10, 10, true)
  ; Attach the ImageLists to the ListView so that it can later display the icons:
  LV_SetImageList(ImageListID1)
  LV_SetImageList(ImageListID2)

  ; Put the files into the ListView:
  GuiControl, 2:-Redraw, EnvironmentListView  ; Improve performance by disabling redrawing during load.
  FileCount := 0  ; Init prior to loop below.
  TotalSize := 0

  Loop %SelectedFullPath%\*.*
    {
    FileGetShortcut, %A_LoopFileFullPath% , QL_OutTarget, QL_OutDir, QL_OutArgs, QL_OutDescription, QL_OutIcon, QL_OutIconNum, QL_OutRunState
    IconNumber := findFileIcon(A_LoopFileFullPath)
    
    ; create an instance of a shortcut
    newShortcut := new Shortcut
    newShortcut.name := A_LoopFileFullPath
    newShortcut.target := QL_OutTarget
    newShortcut.path := QL_OutDir
    newShortcut.args := QL_OutArgs
    newShortcut.app := ""

    ; populate any necessary information.
    examineShortcut(newShortcut)

    row := LV_Add("Icon" . IconNumber, A_LoopFileName, newShortcut.app, newShortcut.target, newShortcut.args)
    }

  LV_ModifyCol()  ; Auto-size each column to fit its contents.

  GuiControl, 2:+Redraw, EnvironmentListView
  }
  ;-------------------------------------------------
  ; return the icon of a given file
  ;-------------------------------------------------
findFileIcon(FileName) {
  
  ; Calculate buffer size required for SHFILEINFO structure.
  sfi_size := A_PtrSize + 8 + (A_IsUnicode ? 680 : 340)
  VarSetCapacity(sfi, sfi_size)

  SplitPath, FileName,,, FileExt  ; Get the file's extension.

  if FileExt in EXE,ICO,ANI,CUR
    {
        ExtID := FileExt  ; Special ID as a placeholder.
        IconNumber := 0  ; Flag it as not found so that these types can each have a unique icon.
    }
  else  ; Some other extension/file-type, so calculate its unique ID.
    {
      ExtID := 0  ; Initialize to handle extensions that are shorter than others.
      Loop 7     ; Limit the extension to 7 characters so that it fits in a 64-bit value.
      {
          ExtChar := SubStr(FileExt, A_Index, 1)
          if not ExtChar  ; No more characters.
              break
          ; Derive a Unique ID by assigning a different bit position to each character:
          ExtID := ExtID | (Asc(ExtChar) << (8 * (A_Index - 1)))
      }
      ; Check if this file extension already has an icon in the ImageLists. If it does,
      ; several calls can be avoided and loading performance is greatly improved,
      ; especially for a folder containing hundreds of files:
      IconNumber := IconArray%ExtID%
    }

  if not IconNumber  ; There is not yet any icon for this extension, so load it.
    {
      ; Get the high-quality small-icon associated with this file extension:
      if not DllCall("Shell32\SHGetFileInfo" . (A_IsUnicode ? "W":"A"), "Str", FileName
          , "UInt", 0, "Ptr", &sfi, "UInt", sfi_size, "UInt", 0x101)  ; 0x101 is SHGFI_ICON+SHGFI_SMALLICON
          IconNumber := 9999999  ; Set it out of bounds to display a blank icon.
      else ; Icon successfully loaded.
      {
          ; Extract the hIcon member from the structure:
          hIcon := NumGet(sfi, 0)
          ; Add the HICON directly to the small-icon and large-icon lists.
          ; Below uses +1 to convert the returned index from zero-based to one-based:
          IconNumber := DllCall("ImageList_ReplaceIcon", "Ptr", ImageListID1, "Int", -1, "Ptr", hIcon) + 1
          DllCall("ImageList_ReplaceIcon", "Ptr", ImageListID2, "Int", -1, "Ptr", hIcon)
          ; Now that it's been copied into the ImageLists, the original should be destroyed:
          DllCall("DestroyIcon", "Ptr", hIcon)
          ; Cache the icon to save memory and improve loading performance:
          IconArray%ExtID% := IconNumber
        }
    }

    return IconNumber
  }
  ;-------------------------------------------------
  ; returns true if no selection of application
  ;-------------------------------------------------
isEmptyApplication() {
  GuiControlGet, selectedApp, , myApplicationDropdownList ; get selected app
  if (selectedApp = "Select application") {
    ShowMsgbox(OK_MESSAGE, "Warning", "Select an Application first")
    Return True
    }
  else
    Return False
  }
  ;---------------------------------------------------------------------
  ; initialize gui with one shortcut
  ;---------------------------------------------------------------------
initializeGui3() {

  ; initialize all fields
  GuiControl, 3:, myEnvName, %selectedEnvironment%  ; update the env.name

  newList := "|" . StrReplace(Applications, "Select application", "Select application|")
  GuiControl,3:, myApplicationDropdownList, %newList%  ; update the shortcut app

  myshortcutName := "xxx"
  GuiControl, 3:, myshortcutName

  myShortcutTarget := "yyy"
  GuiControl, 3:, myShortcutTarget
  }
  ;---------------------------------------------------------------------
  ; load window with the selected shortcut
  ;---------------------------------------------------------------------
loadGui3(selectedRow) {
  
  GuiControl, 3:, myEnvName, %selectedEnvironment%  ; update the env.name
  oldShortcutName := ""
  LV_GetText(shortcutApp, selectedRow, 2)
  newShortcutApp := ShortcutApp = "Pdf" ? (ShortcutApp . "||") : (ShortcutApp . "|")  ; Pdf is last item so add 2 |
  newList := "|" . StrReplace(Applications, shortcutApp, newShortcutApp)
  GuiControl, 3:, myApplicationDropdownList, %newList%  ; update the shortcut app

  LV_GetText(shortcutName, selectedRow, 1)
  GuiControl, 3:, myshortcutName, %shortcutName%  ; update the shortcut name
  oldShortcutName := shortcutName

  Switch ShortcutApp
  {
    Case "VSCode":
    {
      LV_GetText(shortcutArgs, selectedRow, 4)  ; get actual target from args
      ; remove actual args from target
      shortcutTarget := RegExReplace(shortcutArgs, "--new-window")
      shortcutTarget := RegExReplace(shortcutTarget, """")  ; remove double quotes 
      shortcutTarget := Trim(shortcutTarget)
    }

    Case "Notepad++":
    {
      LV_GetText(shortcutArgs, selectedRow, 4)  ; get actual target from args
      ; remove actual args from target
      shortcutTarget := RegExReplace(shortcutArgs, "-nosession")
      shortcutTarget := RegExReplace(shortcutTarget, """")  ; remove double quotes 
      shortcutTarget := Trim(shortcutTarget)
    }

    Default:
      LV_GetText(shortcutTarget, selectedRow, 3)
  }

  GuiControl, 3:, myShortcutTarget, %shortcutTarget%
  ; Gui, 3:Submit, NoHide
  }
  ;-------------------------------------------------------------------------
  ; recursive function to populate the treeview with all environment folders
  ;-------------------------------------------------------------------------
AddSubFoldersToTree(Folder, ParentItemID = 0)
  {
  ; This function adds to the TreeView all subfolders in the specified folder.
  ; It also calls itself recursively to gather nested folders to any depth.
  Loop %Folder%\*.*, 2  ; Retrieve all of Folder's sub-folders.
    {
      AddSubFoldersToTree(A_LoopFileFullPath, TV_Add(A_LoopFileName, ParentItemID, "Icon4"))
    }
  }
  ;---------------------------------------------------------------------
  ; show shortcut gui
  ;---------------------------------------------------------------------
showSubgui3() {
  WinGetPos, targetX, targetY, targetWidth, targetHeight, A
  subGui3_X := targetX + (targetWidth - subGui3_W) / 2
  subGui3_Y := targetY + (targetHeight - subGui3_H) / 2

  ; Gui, 2:+Disabled
  Gui, 3:+OwnDialogs  ; Forces user to dismiss the following dialog before using main window.

  Gui, 3:Show, W%subGui3_W% H%subGui3_h% x%subGui3_X% y%subGui3_Y%, Gui 3
  }
  ;---------------------------------------------------------------------
  ; show environment gui
  ;---------------------------------------------------------------------
showSubgui4() {
  WinGetPos, targetX, targetY, targetWidth, targetHeight, A
  subGui4_X := targetX + (targetWidth - subGui4_W) / 2
  subGui4_Y := targetY + (targetHeight - subGui4_H) / 2

  ; Gui, 2:+Disabled
  Gui, 4:+OwnDialogs  ; Forces user to dismiss the following dialog before using main window.

  Gui, 4:Show, W%subGui4_W% H%subGui4_h% x%subGui4_X% y%subGui4_Y%, Gui 4
  }
  ;-------------------------------------------
  ; Show a message box centered on main window
  ;-------------------------------------------
ShowMsgbox(type, title, message) {
  SetTimer, WinMoveMsgBox, 50
  Sleep 1
  if (type = OK_MESSAGE)
    MsgBox, 4096, %title%, %message%
  else if (type = YES_NO_DANGER_MESSAGE)
    MsgBox, 0x40114, %title%, %message%
  Return

WinMoveMsgBox:
  If WinExist(%title%)
    SetTimer, WinMoveMsgBox, OFF
  
  ; get position & size of main gui
  WinGetPos, targetX, targetY, targetWidth, targetHeight, %mainGui_title%
  newX := targetX + (targetWidth - 100) / 2
  newY := targetY + (targetHeight - 100) / 2

  WinMove, %title%, , %newX%, %newY%
  Return
  }
  ;-------------------------------------
  ; populate any necessary information.
  ;-------------------------------------
examineShortcut(newShortcut) {
  if (newShortcut.name = "")
    return False

  targetApp := ""

  if (RegExMatch(newShortcut.target, "i)\\code.exe$")) {
    targetApp := "VSCode"
  }

  if (RegExMatch(newShortcut.target, "i)\\notepad\+\+.exe$")) {
    targetApp := "Notepad++"
  }

  ; for URLs the address is inside the text file.
  if (RegExMatch(newShortcut.name, "i).url$")) {
    targetApp := "URL"
    file := newShortcut.name
    IniRead, OutputVar, %file%, InternetShortcut, URL
    newShortcut.target := OutputVar
    }

  if (RegExMatch(newShortcut.target, "i).doc[x*]$"))
    targetApp := "Word"

  if (RegExMatch(newShortcut.target, "i).xls[x*|m*]$"))
    targetApp := "Excel"

  if (RegExMatch(newShortcut.target, "i).pdf$"))
    targetApp := "Pdf"
  
  ; when shortcut is a link check if the target is a file or a folder.
  if (targetApp = "" and RegExMatch(newShortcut.name, "i).lnk$"))
    ; {
    ; AttributeString := FileExist(newShortcut.target)
    ; if (AttributeString)
    ;   if (AttributeString = "D")
    ;     targetApp := "Folder"
    ;   else
    ;     targetApp := "Link"
    ; }
    targetApp := "Link"
  
  newShortcut.app := targetApp
  
  }
  ;---------------------------------------------------------------------
  ; create new/delete old and create: shortcut
  ; returns True if shortcut was created successfully
  ; else False.
  ;---------------------------------------------------------------------
createShortcutFile(newApp, newshortcutName, newShortcutTarget) {
  ;
  ; add correct extension to shortcut name.
  ;
  Switch newApp
  {
    Case "URL":
      if (!RegExMatch(newshortcutName, "i).url$"))
        newshortcutName .= ".url"
    Default:
      if (!RegExMatch(newshortcutName, "i).lnk$"))
        newshortcutName .= ".lnk"
  }
  ;
  ; build shortcut full path name.
  ;
  fullShortcutPath := AllEnvironmentsFolder . "\" . selectedSubpath . "\" . newshortcutName

  shortcutDescription := "description of my new shortcut"
  shortcutArgs := ""
  ;
  ; build shortcut target and args.
  ;
  Switch newApp
  {
    case "VSCode":
    {
      selectedTarget := newShortcutTarget
      AttributeString := FileExist(selectedTarget)  ; target may be folder or file
      newShortcutTarget := "C:\Program Files\Microsoft VS Code\Code.exe"
      shortcutArgs := "--new-window " . """" . selectedTarget . """" 
    }

    Case "Notepad++":
    {
      selectedTarget := newShortcutTarget
      AttributeString := FileExist(selectedTarget)  ; target may be folder or file
      newShortcutTarget := "C:\Program Files\Notepad++\notepad++.exe"
      shortcutArgs := "-nosession " . """" . selectedTarget . """" 
    }

    ; case "Folder":
    ; {
    ;   selectedFolder := newShortcutTarget
    ;   AttributeString := FileExist(selectedFolder)  ; target must be folder
    ;   if (AttributeString = "") {
    ;     ShowMsgbox(OK_MESSAGE, "Warning", "Folder does not exist")
    ;     Return False
    ;     }
      
    ;   if (AttributeString != "D") {
    ;     ShowMsgbox(OK_MESSAGE, "Warning", "Target is not a folder")
    ;     Return False
    ;     }
      
    ;   shortcutArgs := ""
    ; }

    case "URL":
      shortcutArgs := ""

    case "Word":
    case "Excel":
    case "Pdf":
    case "Link":
    {
      selectedTarget := newShortcutTarget
      AttributeString := FileExist(selectedTarget)  ; target must be file
      if (AttributeString = "") {
        ShowMsgbox(OK_MESSAGE, "Warning", "File does not exist")
        Return False
        }
      
      ; if (AttributeString = "D") {
      ;   ShowMsgbox(OK_MESSAGE, "Warning", "Target is a folder")
      ;   Return False
      ;   }

      shortcutArgs := ""
    }
  }
  ;
  ; delete shortcut file if it exists
  ;
  if FileExist(fullShortcutPath)
    FileDelete, %fullShortcutPath%

  ; create shortcut file, if no error return True
  if (newApp = "URL") {
    IniWrite, %newShortcutTarget%, %fullShortcutPath%, InternetShortcut, URL
    }
  else {
    FileCreateShortcut, %newShortcutTarget%, %fullShortcutPath%, , %shortcutArgs%, %shortcutDescription%
  }

  if (ErrorLevel) {
    ShowMsgbox(OK_MESSAGE, "Warning", "Could not create the shortcut")
    Return False
    }
  else {
    ; delete old shortcut if changed name.    
    if (oldShortcutName <> newshortcutName) {
      fullShortcutPath := AllEnvironmentsFolder . "\" . selectedSubpath . "\" . oldShortcutName
      FileDelete, %fullShortcutPath%
      }
    Return True
    }

  }
  ;---------------------------------------------------------------------
  ; hot key valid only on file selection gui.
  ; special thanks to MilesAhead for his solution:
  ;   https://autohotkey.com/board/topic/86709-fileselectfolder-and-fileselectfile-in-one-selection/?p=556102
  ;---------------------------------------------------------------------
~!RButton::
  IfWinActive %FolderPrompt%
  {
    Clipboard =
    SelectedFileOrFolder := ""
    Send ^c
    ClipWait,2
    SelectedFileOrFolder = %Clipboard%
    Send {Esc}
  }
  return
  ;---------------------------------------------------------------------
  ; select file or folder
  ;---------------------------------------------------------------------
fileFolderSelector(filter, Prompt = "Alt Right Mouse Click to select Folder") {

  Gui, +OwnDialogs  ; Forces user to dismiss the following dialog before using main window.

  global FolderPrompt := Prompt
  global SelectedFileOrFolder

  ; get last used folder from ini file.
  IniRead, lastFolderSelection, %INI_file%, general, lastFolderSelection
  if (lastFolderSelection = "")
    lastFolderSelection := "D:\_files\nic\pc-setups\AutoHotkey macros\nic apps"

  FileSelectFile,DummyVar, 34, %lastFolderSelection%, %FolderPrompt%  ; 34 = 2 + 32
  
  ; if a file was selected then return the filename.
  if (DummyVar <> "") {
    SplitPath, DummyVar, selectedFileName, selectedDir, selectedExtension, selectedNameNoExt, selectedDrive
    IniWrite, %selectedDir%, %A_ScriptDir%\%INI_file%, general, lastFolderSelection ; save last used path
    return DummyVar
    }

  if (SelectedFileOrFolder <> "") {
    SplitPath, SelectedFileOrFolder, selectedFileName, selectedDir, selectedExtension, selectedNameNoExt, selectedDrive
    IniWrite, %selectedDir%, %A_ScriptDir%\%INI_file%, general, lastFolderSelection ; save last used path
    }
  
  ; return the clipboard that contains a file or folder name.
  return %SelectedFileOrFolder%
  }
  ;-------------------------------------------------------------
  ; return appropriate file filter based on selected application
  ;-------------------------------------------------------------
getFileFilter() {
  GuiControlGet, selectedApp, , myApplicationDropdownList ; get selected app

  switch selectedApp
  {
    case "VSCode":
    case "Folder":
    case "Link":
      filter := ""
    case "URL":
      filter := "*.htm; *.url; *.html"
    case "Word":
      filter := "*.doc*"
    case "Excel":
      filter := "*.xls*"
    case "pdf":
      filter := "*.pdf"
    default:
      filter := ""
  }
  Return filter
  }
  ;--------------------------------
  ; shortcut definition as a class
  ;--------------------------------
class Shortcut {
  name := ""    ; the shortcut filename
  target := ""  ; target app opening it, or the file itself
  path := ""    ; full file path
  args := ""    ; the args if necessary
  app := ""     ; the app that opens it
  }

#include %A_ScriptDir%\GuiCenterButtons.ahk