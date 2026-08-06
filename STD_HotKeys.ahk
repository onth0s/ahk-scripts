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

Persistent() ; <--- CRITICAL FIX: Forces script to stay alive in the background

ComPort := "COM5"   ; Your Nano's COM port
BaudRate := 9600

; ═══ BUTTON GRID ═════════════════════════════════════════════════════════
; ═══ BUTTON GRID ═════════════════════════════════════════════════════════
; ═══ BUTTON GRID ═════════════════════════════════════════════════════════

; --- NATIVE WINDOWS SERIAL CONNECTION ---
hCom := DllCall("CreateFile"
    , "Str", "\\.\" . ComPort
    , "UInt", 0xC0000000  ; GENERIC_READ | GENERIC_WRITE
    , "UInt", 0           ; No sharing
    , "Ptr", 0            ; Security attributes
    , "UInt", 3           ; OPEN_EXISTING
    , "UInt", 0           ; Flags
    , "Ptr", 0, "Ptr")

if (hCom == -1 || hCom == 0) {
    MsgBox("Failed to open " . ComPort . ". Ensure Arduino IDE Serial Monitor is closed.", "Error", 16)
    ExitApp
}

; CRITICAL FIX: Give the Arduino 2 seconds to reboot after the DTR toggle
Sleep(2000) 

; Build DCB safely using Windows API parser string
DCB := Buffer(28, 0)       ; FIX: DCB struct size is exactly 28 bytes
NumPut("UInt", 28, DCB, 0) ; Set DCBlength

if !DllCall("GetCommState", "Ptr", hCom, "Ptr", DCB) {
    MsgBox("Failed to get COM state.", "Error", 16)
    ExitApp
}

; Use BuildCommDCB to avoid manual struct bitfield offset corruption
if !DllCall("BuildCommDCBW", "Str", "baud=" . BaudRate . " parity=N data=8 stop=1", "Ptr", DCB) {
    MsgBox("Failed to build DCB config.", "Error", 16)
    ExitApp
}

if !DllCall("SetCommState", "Ptr", hCom, "Ptr", DCB) {
    MsgBox("Failed to set COM state.", "Error", 16)
    ExitApp
}

; Toggle DTR & RTS lines to wake up Arduino Nano USB-Serial chip
SETRTS := 3, SETDTR := 5
DllCall("EscapeCommFunction", "Ptr", hCom, "UInt", SETDTR)
DllCall("EscapeCommFunction", "Ptr", hCom, "UInt", SETRTS)

; Set Timeouts (non-blocking read)
Timeouts := Buffer(20, 0)
NumPut("UInt", 0xFFFFFFFF, Timeouts, 0) ; FIX: Safer UInt mapping for MAXDWORD
DllCall("SetCommTimeouts", "Ptr", hCom, "Ptr", Timeouts)

OnExit((*) => DllCall("CloseHandle", "Ptr", hCom))

ReadBuffer := ""

; Poll buffer every 30ms
SetTimer ReadSerial, 30

ReadSerial() {
    global hCom, ReadBuffer, SessionLocked
    buf := Buffer(64, 0)
    bytesRead := 0
    
    ; Pass buf.Ptr to Write/Read raw memory correctly
    if DllCall("ReadFile", "Ptr", hCom, "Ptr", buf.Ptr, "UInt", 64, "UInt*", &bytesRead, "Ptr", 0) && bytesRead > 0 {
        ReadBuffer .= StrGet(buf.Ptr, bytesRead, "UTF-8")
        
        ; Process complete line when newline received
        while InStr(ReadBuffer, "`n") {
            pos := InStr(ReadBuffer, "`n")
            line := Trim(SubStr(ReadBuffer, 1, pos - 1), "`r`n ")
            ReadBuffer := SubStr(ReadBuffer, pos + 1)
            
            if (line != "") {
                if !SessionLocked
                    DispatchMacro(line)
            }
        }
    }
}

; --- MACRO MAPPINGS ---
DispatchMacro(cmd) {
    global DoubleTapTaps, DoubleTapLastKey
    if (DoubleTapLastKey != cmd)
        DoubleTapTaps.Clear()   ; any other key cancels pending taps
    switch cmd {
        ; ═══ LAYER 1 ═════════════════════════════
        case "L1_K_01": 
            ToolTip("Launching Sublime Text...")
            Run('"C:\Program Files\Sublime Text\sublime.exe"')
        case "L1_K_02": ToolTip("L1__B_02")
        case "L1_K_03":
            if ProcessExist("krita.exe") {
                ToolTip("Double-tap to paste image in BeeRef")
                DoubleTap("L1_K_03", () => LaunchBeeRefAndPasteImage())
            } else {
                ToolTip("Launching Krita...")
                ShellRun('C:\Program Files\Krita (x64)\bin\krita.exe')
            }
        case "L1_K_04": ToolTip("L1__B_04")
        case "L1_K_05": ToolTip("L1__B_05")
        case "L1_K_06": ToolTip("L1__B_06")
        case "L1_K_07": ToolTip("L1__B_07")
        case "L1_K_08": ToolTip("L1__B_08")
        case "L1_K_09": ToolTip("L1__B_09")
        ; KEY 10 is reserved for hardware layer switching
        ; L1_K_11: open opencode in Windows Terminal at the clipboard path
        case "L1_K_11":
            raw := Trim(A_Clipboard, " `t`r`n")
            raw := RegExReplace(raw, '^"|"$')        ; strip Copy-as-path quotes
            if RegExMatch(raw, '^file:///')
                raw := StrReplace(SubStr(raw, 8), "/", "\")
            raw := ExpandTilde(raw)

            if !raw {
                ToolTip("Clipboard is empty — copy a path first")
                SetTimer(() => ToolTip(), -2000)
            } else if DirExist(raw) {
                LaunchOpencode(raw)
            } else if FileExist(raw) {
                SplitPath(raw, , &dir)               ; file path → its folder
                LaunchOpencode(dir)
            } else {
                ToolTip("Not a valid path: " raw)
                SetTimer(() => ToolTip(), -2000)
            }
        case "L1_K_12":
            DoubleTap("L1_K_12", () => Send("^#{x}"))

        ; ═══ LAYER 2 ═════════════════════════════
        case "L2_K_01": ToolTip("L2__B_01")
        case "L2_K_02": ToolTip("L2__B_02")
        case "L2_K_03": ToolTip("L2__B_03")
        case "L2_K_04": ToolTip("L2__B_04")
        case "L2_K_05": ToolTip("L2__B_05")
        case "L2_K_06": ToolTip("L2__B_06")
        case "L2_K_07": ToolTip("L2__B_07")
        case "L2_K_08": ToolTip("L2__B_08")
        case "L2_K_09": ToolTip("L2__B_09")
        ; KEY 10 is reserved for hardware layer switching
        case "L2_K_11": ToolTip("L2__B_11")
        case "L2_K_12": ToolTip("L2__B_12")
    }
    
    ; Clear the tooltip automatically after 1 second
    SetTimer(() => ToolTip(), -1000) 
}

; True when the workstation is locked (Win+L / secure desktop).
; Event-driven: Windows raises WM_WTSSESSION_CHANGE (0x2B1) on lock/unlock.
; Polling WTSConnectState is unreliable (often stays WTSActive on Win+L).
SessionLocked := false

RegisterSessionMonitor() {
    global SessionLocked
    if !DllCall("wtsapi32.dll\WTSRegisterSessionNotificationEx"
        , "Ptr", 0, "Ptr", A_ScriptHwnd, "UInt", 1)   ; NOTIFY_FOR_ALL_SESSIONS
        return false
    OnMessage(0x02B1, WM_WTSSESSION_CHANGE)
    ; Sync in case the script started while already locked: foreground is
    ; LockApp.exe during the lock curtain; no active window on secure logon.
    SessionLocked := !WinExist("A") || (WinGetProcessName("A") = "LockApp.exe")
    return true
}

WM_WTSSESSION_CHANGE(wParam, lParam, msg, hwnd) {
    global SessionLocked
    if (wParam = 0x7)        ; WTS_SESSION_LOCK
        SessionLocked := true
    else if (wParam = 0x8)   ; WTS_SESSION_UNLOCK
        SessionLocked := false
}

if !RegisterSessionMonitor()
    ToolTip("Session monitor failed to register")

; ── Double-tap state ──
; Pending taps per key (keyName → last press tick) + last key that engaged DoubleTap.
DoubleTapTaps   := Map()
DoubleTapLastKey := ""

; Fire `action` only when `keyName` is pressed twice within `window` ms.
; A different key pressed in between cancels the pending tap (anti-misfire).
DoubleTap(keyName, action, window := 400) {
    global DoubleTapTaps, DoubleTapLastKey
    if (DoubleTapLastKey != keyName) {
        DoubleTapTaps.Clear()
        DoubleTapLastKey := keyName
    }
    if DoubleTapTaps.Has(keyName) && (A_TickCount - DoubleTapTaps[keyName]) <= window {
        DoubleTapTaps.Delete(keyName)
        action()
        return
    }
    DoubleTapTaps[keyName] := A_TickCount
}

; Launch BeeRef and let it paste the clipboard image itself via --paste.
; The GUI window belongs to the child pythonw.exe process (pip distlib
; launcher spawns it and waits), so match that, NOT beeref.exe.
LaunchBeeRefAndPasteImage() {
    ShellRun('C:\Users\Leonardo\001\00__DEV\BeeRef\.venv\Scripts\beeref.exe', '--paste')
    if WinWait("ahk_exe pythonw.exe", , 5)
        WinActivate("ahk_exe pythonw.exe")
}

; ═══ BUTTON GRID ═════════════════════════════════════════════════════════
; ═══ BUTTON GRID ═════════════════════════════════════════════════════════
; ═══ BUTTON GRID ═════════════════════════════════════════════════════════

; ═══ CONFIGURATION ════════════════════════════════════════════════════════════
; Tunable values — edit these to adjust behavior without touching logic.

; Terminal opacity toggle
OPACITY_HIGH := 90
OPACITY_LOW  := 65

; Terminal settings.json path (Windows Terminal)
TERMINAL_SETTINGS_PATH := EnvGet("LOCALAPPDATA") . "\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

; Win+F1: Resize Windows Terminal
TERMINAL_WIDTH_PCT  := 0.74
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

; Ctrl+Alt+Win+ñ — Reload the script via the upkey shell command
^#!ñ::
{
    MsgBox("Script reloaded!", "Success", "Iconi T1")
    Run('pwsh.exe -NoLogo -Command ". $PROFILE; upkey"')
}

; Ctrl+Alt+Win+p — Open this script in the default editor
^#!p::
{
    Run('edit "' A_ScriptFullPath '"')
}

; Win+E — Open Downloads in File Explorer
#e::
{
    Run 'explorer.exe "C:\Users\Leonardo\Downloads"'
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

; Ctrl+Numpad3 sends e
$^Numpad3::Send("e")

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
#F1:: ResizeTerminal()
#HotIf  ; ── end context ──

; Apply the standard Win+F1 size to a Windows Terminal window (default: active)
ResizeTerminal(hwnd := 0) {
    if !hwnd
        hwnd := WinExist("A")
    if !hwnd
        return
    WinMove(TERMINAL_OFFSET_X, TERMINAL_OFFSET_Y,
        A_ScreenWidth * TERMINAL_WIDTH_PCT - 3, A_ScreenHeight * TERMINAL_HEIGHT_PCT + 2, "ahk_id " hwnd)
}

; Run a program at user (non-elevated) integrity level via the desktop shell.
; Source: AutoHotkeyUX/inc/ShellRun.ahk (Lexikos), AHK v2 port.
ShellRun(filePath, arguments?, directory?, operation?, show?) {
    static VT_UI4 := 0x13, SWC_DESKTOP := ComValue(VT_UI4, 0x8)
    ComObject("Shell.Application").Windows.Item(SWC_DESKTOP).Document.Application
        .ShellExecute(filePath, arguments?, directory?, operation?, show?)
}

; Expand a leading "~" (pwsh-style home) to the user profile directory.
; Accepts "~/path", "~\" or bare "~". Other input is returned unchanged.
ExpandTilde(path) {
    if path = "~"
        return EnvGet("USERPROFILE")
    if RegExMatch(path, '^~[\\/]')
        return EnvGet("USERPROFILE") . SubStr(path, 2)
    return path
}

; Launch opencode in Windows Terminal at the given directory, then size the
; terminal window to the same dimensions Win+F1 uses.
; wt.exe is launched de-elevated so it can attach to existing (non-elevated)
; terminals as a new tab, or spawn a fresh window when none are running.
LaunchOpencode(dir) {
    wtPath := EnvGet("LOCALAPPDATA") . "\Microsoft\WindowsApps\wt.exe"
    before := WinGetList("ahk_class CASCADIA_HOSTING_WINDOW_CLASS")

    ShellRun(wtPath, '-d "' dir '" pwsh.exe -NoExit -Command "opencode"')

    if WinWait("ahk_class CASCADIA_HOSTING_WINDOW_CLASS", , 5) {
        Sleep(400)
        target := 0
        for w in WinGetList("ahk_class CASCADIA_HOSTING_WINDOW_CLASS") {
            wasOpen := false
            for b in before {
                if b = w {
                    wasOpen := true
                    break
                }
            }
            if !wasOpen {
                target := w          ; a brand-new window was created
                break
            }
        }
        if !target && before.Length > 0
            target := before[1]      ; tab landed in existing topmost window

        if target {
            WinActivate("ahk_id " target)
            WinWaitActive("ahk_id " target, , 3)
            ResizeTerminal(target)
        }
    }
}

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
