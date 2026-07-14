#Requires AutoHotkey v2.0
#SingleInstance Force
SetTitleMatchMode 2 ; <--- Crucial: Allows partial matching for window criteria

^#!ñ::
{
    MsgBox("Script reloaded!", "Success", "Iconi T1")
    Reload()
}

^#!p::
{
    Run('edit "C:\Users\Leonardo\001\00__DEV\zz - VAR\AutoHotkey\test_01.ahk"')
}

; Force Admin Privileges
if !A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    ExitApp()
}

; --- HOTKEY 1: Open Windows Terminal (Global) ---
^#t:: {
    Run("shell:AppsFolder\Microsoft.WindowsTerminal_8wekyb3d8bbwe!App")
}

; --- HOTKEY 2: Toggle Terminal Opacity (Terminal Only) ---
#HotIf WinActive("ahk_exe WindowsTerminal.exe")
!F1:: {
    settingsPath := "C:\Users\Leonardo\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    
    if !FileExist(settingsPath) {
        return
    }
    
    fileContent := FileRead(settingsPath)
    
    if InStr(fileContent, '"opacity": 90') {
        fileContent := StrReplace(fileContent, '"opacity": 90', '"opacity": 65')
    } else if InStr(fileContent, '"opacity": 65') {
        fileContent := StrReplace(fileContent, '"opacity": 65', '"opacity": 90')
    } else {
        fileContent := RegExReplace(fileContent, '"opacity":\s*\d+', '"opacity": 90')
    }
    
    try {
        FileObj := FileOpen(settingsPath, "w", "UTF-8")
        FileObj.Write(fileContent)
        FileObj.Close()
    }
}

#HotIf WinActive("Settings ahk_class ApplicationFrameWindow")
#F1:: {
    activeWin := WinExist("A") 
    if activeWin {
        WinMove(0, 7, 495, 700, "ahk_id " activeWin)
    }
}

#HotIf ; Reset context to default

#HotIf WinActive("ahk_exe Dimmer.exe")
#F1:: {
    WinMove(7, 709, , , "A")
}

#HotIf ; Reset context to default

; =========================================================================
; 1. Base Rebind: Make Caps Lock act exactly like Left Shift everywhere
; =========================================================================
*CapsLock:: {
    Send "{Blind}{LShift DownR}"
}

*CapsLock up:: {
    Send "{Blind}{LShift Up}"
}

; =========================================================================
; 2. Contextual Exceptions (While CapsLock is physically held down)
; =========================================================================
#HotIf GetKeyState("CapsLock", "P")

; Caps Lock + Esc -> Toggle actual Caps Lock light/state
*Esc:: {
    SetCapsLockState(!GetKeyState("CapsLock", "T"))
}

#HotIf ; Reset context

; Pressing F2 sends 3
$F2::Send("3")

; Pressing Alt + F2 sends the actual F2 function
$!F2::Send("{F2}")


; 1. Pressing F10 sends 9
$F10::Send("9")

; 2. Pressing Shift + F10 sends )
$+F10::Send(")")

; 3. Pressing Alt + F10 sends the actual F10 function
$!F10::Send("{F10}")

#HotIf ; Reset hotkey context

; ==========================================
;  DEBUGGING SHORTCUT: Ctrl+Alt+Shift+Win+.
; ==========================================
^!+#.:: {
    ; Get ID, Title, and Class of the active window
    activeHWnd := WinExist("A")
    if !activeHWnd {
        ToolTip("No active window detected.")
        SetTimer(() => ToolTip(), -2000)
        return
    }
    
    winTitle := WinGetTitle(activeHWnd)
    winClass := WinGetClass(activeHWnd)
    winProcess := WinGetProcessName(activeHWnd)
    
    ; Get position and size
    WinGetPos(&x, &y, &width, &height, activeHWnd)
    
    ; Format the debug message
    debugMsg := "
    (
        Active Window Stats:
        ---------------------------------
        Title:    `t{1}
        Class:    `tahk_class {2}
        Process:  `t{3}
        ID:       `tahk_id {4}
        
        Position: `tX: {5}, Y: {6}
        Size:     `tW: {7}, H: {8}
    )"
    
    formattedMsg := Format(debugMsg, winTitle, winClass, winProcess, activeHWnd, x, y, width, height)
    
    ; Show info in a popup box
    MsgBox(formattedMsg, "Window Info Debugger", "64")
}

#HotIf ; Reset hotkey context

; ==============================================================================
; 0. OVERRIDE MS OFFICE/M365 GLOBAL INTERCEPT
; Prevents Ctrl+Alt+Shift+Win from launching m365.cloud.microsoft on release.
; ==============================================================================
#^!Shift::
#^+Alt::
#!+Ctrl::
^!+LWin:: {
    Send("{Blind}{vk07}")
}

#HotIf ; Reset hotkey context

; ==========================================
; 1. PRESS Win+F1 TO RESIZE WINDOWS TERMINAL
; ==========================================
#HotIf WinActive("ahk_class CASCADIA_HOSTING_WINDOW_CLASS")
#F1:: { ; Added '#' here for the Windows key modifier
    activeHWnd := WinExist("A")
    targetWidth := A_ScreenWidth * 0.75
    targetHeight := A_ScreenHeight * 0.85 
    targetX := 25
    targetY := 25 + 7

    WinMove(targetX, targetY, targetWidth, targetHeight, activeHWnd)
}

#HotIf ; Reset hotkey context

; ==========================================
; 2. PRESS Win+F1 TO SNAP TASK MANAGER TO MONITOR 1 (RIGHT SIDE, 55% WIDTH)
; ==========================================
#HotIf WinActive("ahk_class TaskManagerWindow")
#F1:: {
    activeHWnd := WinExist("A")
    
    ; Retrieve the boundary coordinates of Monitor 1's work area (excluding taskbar)
    ; This creates variables: left, top, right, bottom
    try {
        MonitorGetWorkArea(1, &left, &top, &right, &bottom)
        
        ; Calculate the total work area dimensions
        monitorWidth := right - left
        monitorHeight := bottom - top
        
        ; Calculate target size (55% width, 100% height)
        targetWidth := monitorWidth * 0.58
        targetHeight := monitorHeight + 7
        
        ; Position it flush against the right edge of Monitor 1
        targetX := right - targetWidth + 7
        targetY := top
        
        ; Move and resize
        WinMove(targetX, targetY, targetWidth, targetHeight, activeHWnd)
    } catch {
        ToolTip("Failed to detect Monitor 1.")
        SetTimer(() => ToolTip(), -2000)
    }
}

#HotIf