; STD_HotKeys.ahk ──────────────────────────────────────────────────────────────
; Personal hotkey customizations for Windows.
; Requires AutoHotkey v2.0
; ──────────────────────────────────────────────────────────────────────────────

#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn VarUnset, Off  ; Suppress false positive on built-in A_* variables
SetTitleMatchMode 2  ; Partial matching for window title criteria

; ═══ ADMIN ESCALATION ═════════════════════════════════════════════════════════
; Re-launches the script with admin privileges if not already elevated.
if !A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    ExitApp()
}

; ═══ BUTTON GRID ══════════════════════════════════════════════════════════════

ComPort := "COM5"   ; Your Nano's COM port
BaudRate := 9600

; --- NATIVE WINDOWS SERIAL CONNECTION ---
hCom := DllCall("CreateFile", "Str", "\\.\" . ComPort
    , "UInt", 0xC0000000  ; GENERIC_READ | GENERIC_WRITE
    , "UInt", 0           ; No sharing
    , "Ptr", 0            ; Security attributes
    , "UInt", 3           ; OPEN_EXISTING
    , "UInt", 0           ; Flags
    , "Ptr", 0, "Ptr")

if (hCom == -1 || hCom == 0) {
    MsgBox("Failed to open " . ComPort . ". Ensure Arduino Serial Monitor is closed.", "Error", 16)
    ExitApp
}

; Set DCB (Device Control Block) settings: 9600-8-N-1
DCB := Buffer(28, 0)
NumPut("UInt", 28, DCB, 0)
DllCall("GetCommState", "Ptr", hCom, "Ptr", DCB)
NumPut("UInt", BaudRate, DCB, 4)  ; BaudRate
NumPut("UChar", 8, DCB, 18)        ; ByteSize (8)
NumPut("UChar", 0, DCB, 19)        ; Parity (None)
NumPut("UChar", 0, DCB, 20)        ; StopBits (1)
DllCall("SetCommState", "Ptr", hCom, "Ptr", DCB)

; Set Timeouts (non-blocking read)
Timeouts := Buffer(20, 0)
NumPut("UInt", -1, Timeouts, 0) ; ReadIntervalTimeout
DllCall("SetCommTimeouts", "Ptr", hCom, "Ptr", Timeouts)

OnExit((*) => DllCall("CloseHandle", "Ptr", hCom))

; Poll buffer every 30ms
SetTimer ReadSerial, 30

ReadBuffer := ""

ReadSerial() {
    global hCom, ReadBuffer
    buf := Buffer(64, 0)
    bytesRead := 0
    
    if DllCall("ReadFile", "Ptr", hCom, "Ptr", buf, "UInt", 64, "UInt*", &bytesRead, "Ptr", 0) && bytesRead > 0 {
        ReadBuffer .= StrGet(buf, bytesRead, "UTF-8")
        
        ; Process complete line when newline received
        while InStr(ReadBuffer, "`n") {
            pos := InStr(ReadBuffer, "`n")
            line := Trim(SubStr(ReadBuffer, 1, pos - 1), "`r`n ")
            ReadBuffer := SubStr(ReadBuffer, pos + 1)
            
            if (line != "") {
                DispatchMacro(line)
            }
        }
    }
}

; --- MACRO MAPPINGS ---
DispatchMacro(cmd) {
    switch cmd {
        case "KEY_1":  Send("^c")
        case "KEY_2":  Send("^v")
        case "KEY_3":  Send("^z")
        case "KEY_4":  Send("^+z")
        case "KEY_5":  SoundSetVolume("+5")
        case "KEY_6":  SoundSetVolume("-5")
        case "KEY_7":  SoundSetMute(-1)
        case "KEY_8":  Run("calc.exe")
        case "KEY_9":  Run("notepad.exe")
        case "KEY_10": Send("{Media_Play_Pause}")
        case "KEY_11": Send("{Media_Next}")
        case "KEY_12": MsgBox("ButtonGrid Connected & Triggered Successfully!")
    }
}

; ═══ CONFIGURATION ════════════════════════════════════════════════════════════
; Tunable values — edit these to adjust behavior without touching logic.

; Terminal opacity toggle
OPACITY_HIGH := 90
OPACITY_LOW  := 65

; Terminal settings.json path (Windows Terminal)
TERMINAL_SETTINGS_PATH := EnvGet("LOCALAPPDATA") . "\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

; Win+F1: Resize Windows Terminal
TERMINAL_WIDTH_PCT  := 0.75
TERMINAL_HEIGHT_PCT := 0.85
TERMINAL_OFFSET_X   := 25
TERMINAL_OFFSET_Y   := 32

; Win+F1: Snap Task Manager to right side of Monitor 1
TASKMANAGER_WIDTH_PCT := 0.58

; Win+F1: Reposition Settings app
SETTINGS_X := 0
SETTINGS_Y := 7
SETTINGS_W := 495
SETTINGS_H := 700

; Win+F1: Reposition Dimmer
DIMMER_X := 7
DIMMER_Y := 709

; ═══ SYSTEM SHORTCUTS ═════════════════════════════════════════════════════════

; Ctrl+Alt+Win+ñ — Reload the script
^#!ñ::
{
    MsgBox("Script reloaded!", "Success", "Iconi T1")
    Reload()
}

; Ctrl+Alt+Win+p — Open this script in the default editor
^#!p::
{
    Run('edit "' A_ScriptFullPath '"')
}

; Ctrl+Win+T — Launch Windows Terminal
^#t:: {
    Run("shell:AppsFolder\Microsoft.WindowsTerminal_8wekyb3d8bbwe!App")
}

; Ctrl+Alt+Shift+Win (all combos) — Block Office/M365 global intercept.
; Prevents the key combo from launching m365.cloud.microsoft on release.
#^!Shift::
#^+Alt::
#!+Ctrl::
^!+LWin:: {
    Send("{Blind}{vk07}")
}

; Ctrl+Alt+Win+Left — Previous media track
^#!Left:: {
    Send("{Media_Prev}")
}

; Ctrl+Alt+Win+Right — Next media track
^#!Right:: {
    Send("{Media_Next}")
}

; Ctrl+Alt+Win+Up — Volume up by 1
^#!Up:: {
    SoundSetVolume("+1")
}

; Ctrl+Alt+Win+Down — Volume down by 1
^#!Down:: {
    SoundSetVolume("-1")
}

; ═══ KEY REMAPS ═══════════════════════════════════════════════════════════════

; CapsLock → Left Shift (global passthrough)
*CapsLock:: {
    Send "{Blind}{LShift DownR}"
}

*CapsLock up:: {
    Send "{Blind}{LShift Up}"
}

; While CapsLock is physically held: Esc toggles the actual CapsLock state/light
#HotIf GetKeyState("CapsLock", "P")
*Esc:: {
    SetCapsLockState(!GetKeyState("CapsLock", "T"))
}
#HotIf  ; ── end context ──

; F2 sends 3
$F2::Send("3")

; Alt+F2 sends the real F2
$!F2::Send("{F2}")

; F10 sends 9
$F10::Send("9")

; Shift+F10 sends )
$+F10::Send(")")

; Alt+F10 sends the real F10
$!F10::Send("{F10}")

; Ctrl+Numpad1 sends 4
$^Numpad1::Send("4")

; Alt+4 sends # (hash)
!4::SendText("#")

; ═══ TERMINAL OPACITY ═════════════════════════════════════════════════════════
; Alt+F1 toggles Windows Terminal opacity by rewriting its settings.json.
; Cycles: 90% → 65% → whatever was set → 90%.

#HotIf WinActive("ahk_exe WindowsTerminal.exe")
!F1:: {
    if !FileExist(TERMINAL_SETTINGS_PATH) {
        return
    }

    fileContent := FileRead(TERMINAL_SETTINGS_PATH)

    if InStr(fileContent, '"opacity": ' OPACITY_HIGH) {
        fileContent := StrReplace(fileContent, '"opacity": ' OPACITY_HIGH, '"opacity": ' OPACITY_LOW)
    } else if InStr(fileContent, '"opacity": ' OPACITY_LOW) {
        fileContent := StrReplace(fileContent, '"opacity": ' OPACITY_LOW, '"opacity": ' OPACITY_HIGH)
    } else {
        fileContent := RegExReplace(fileContent, '"opacity":\s*\d+', '"opacity": ' OPACITY_HIGH)
    }

    try {
        FileObj := FileOpen(TERMINAL_SETTINGS_PATH, "w", "UTF-8")
        FileObj.Write(fileContent)
        FileObj.Close()
    } catch as err {
        ToolTip("Failed to write Terminal settings: " err.Message)
        SetTimer(() => ToolTip(), -3000)
    }
}
#HotIf  ; ── end context ──

; ═══ WINDOW MANAGEMENT ════════════════════════════════════════════════════════
; Win+F1 snaps/resizes the active window depending on which app is focused.

; Win+F1: Resize Settings app to fixed position
#HotIf WinActive("Settings ahk_class ApplicationFrameWindow")
#F1:: {
    activeWin := WinExist("A")
    if activeWin {
        WinMove(SETTINGS_X, SETTINGS_Y, SETTINGS_W, SETTINGS_H, "ahk_id " activeWin)
    }
}
#HotIf  ; ── end context ──

; Win+F1: Reposition Dimmer to bottom-left of screen
#HotIf WinActive("ahk_exe Dimmer.exe")
#F1:: {
    WinMove(DIMMER_X, DIMMER_Y, , , "A")
}
#HotIf  ; ── end context ──

; Win+F1: Resize Windows Terminal to 75% × 85% of screen, offset from top-left
#HotIf WinActive("ahk_class CASCADIA_HOSTING_WINDOW_CLASS")
#F1:: {
    activeHWnd := WinExist("A")
    targetWidth  := A_ScreenWidth * TERMINAL_WIDTH_PCT
    targetHeight := A_ScreenHeight * TERMINAL_HEIGHT_PCT
    WinMove(TERMINAL_OFFSET_X, TERMINAL_OFFSET_Y, targetWidth, targetHeight, activeHWnd)
}
#HotIf  ; ── end context ──

; Win+F1: Snap Task Manager to right 58% of Monitor 1
#HotIf WinActive("ahk_class TaskManagerWindow")
#F1:: {
    activeHWnd := WinExist("A")

    try {
        MonitorGetWorkArea(1, &left, &top, &right, &bottom)

        monitorWidth  := right - left
        monitorHeight := bottom - top

        targetWidth  := monitorWidth * TASKMANAGER_WIDTH_PCT
        targetHeight := monitorHeight + 9

        ; Flush against the right edge, vertically centered
        targetX := right - targetWidth + 7
        targetY := top - 1

        WinMove(targetX, targetY, targetWidth, targetHeight, activeHWnd)
    } catch {
        ToolTip("Failed to detect Monitor 1.")
        SetTimer(() => ToolTip(), -2000)
    }
}
#HotIf  ; ── end context ──

; ═══ DEBUG TOOLS ══════════════════════════════════════════════════════════════

; Ctrl+Alt+Shift+Win+. — Show active window info (title, class, process, position, size)
^!+#.:: {
    activeHWnd := WinExist("A")
    if !activeHWnd {
        ToolTip("No active window detected.")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    winTitle   := WinGetTitle(activeHWnd)
    winClass   := WinGetClass(activeHWnd)
    winProcess := WinGetProcessName(activeHWnd)

    WinGetPos(&x, &y, &width, &height, activeHWnd)

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

    MsgBox(formattedMsg, "Window Info Debugger", "64")
}
