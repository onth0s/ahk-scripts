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
; ═══ CONFIGURATION ════════════════════════════════════════════════════════════
; Tunable values — edit these to adjust behavior without touching logic.

; Hardware serial button grid
ComPort  := "COM5"   ; Nano COM port
BaudRate := 9600

; External applications & paths
DIR_DOWNLOADS := "C:\Users\Leonardo\Downloads"
APP_SUBLIME   := 'C:\Program Files\Sublime Text\sublime.exe'
APP_KRITA     := 'C:\Program Files\Krita (x64)\bin\krita.exe'
APP_BLENDER   := 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
APP_TELEGRAM  := 'C:\Users\Leonardo\AppData\Roaming\Telegram Desktop\Telegram.exe'
APP_BEEREF    := 'C:\Users\Leonardo\001\00__DEV\BeeRef\.venv\Scripts\beeref.exe'
APP_WT        := EnvGet("LOCALAPPDATA") . "\Microsoft\WindowsApps\wt.exe"
APP_EXPLORER  := 'C:\Windows\explorer.exe'

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

; Win+F1: Snap Task Manager to the right 58% of the monitor it's on
TASKMANAGER_WIDTH_PCT := 0.58
; On a 1920x1080 monitor: snap flush to the top-right at this fraction of height,
; 40% width, nudged 5px toward the right edge
TASKMANAGER_1080P_HEIGHT_PCT := 0.50
TASKMANAGER_1080P_WIDTH_PCT := 0.41
TASKMANAGER_1080P_X_OFFSET := 9
TASKMANAGER_1080P_Y_OFFSET := -1

; Win+F1: Resize Microsoft Edge (raw width px, height as % of work area, nudged left)
; *_OFFSET stubs are fine-tune deltas added on top (default 0) for XY position and size.
EDGE_WIDTH_PX       := 1400
EDGE_HEIGHT_PCT     := 1
EDGE_X_OFFSET       := -10
EDGE_POS_X_OFFSET   := 0
EDGE_POS_Y_OFFSET   := -2
EDGE_SIZE_W_OFFSET  := 0
EDGE_SIZE_H_OFFSET  := 10

; Win+F1: Reposition Settings app
SETTINGS_X := 0
SETTINGS_Y := 7
SETTINGS_W := 495
SETTINGS_H := 700

; Win+F1: Reposition Dimmer
DIMMER_X := 7
DIMMER_Y := 709

; Numpad grid (AutoHotInterception)
NUMGRID_SECONDARY_VID := 0x248A
NUMGRID_SECONDARY_PID := 0x8367
; Default keyboard: ACPI embedded keyboard. Resolved by handle (ids can shift
; across reboots). List extra candidate handles if the physical keyboard spans
; more than one HID collection.
NUMGRID_DEFAULT_HANDLES := [
    "ACPI\VEN_MSNB&DEV_1001",
]
NUMGRID_POLL_MS := 2000
; ═══ CORE UTILITIES ═══════════════════════════════════════════════════════════
; Shared runtime helpers: notifications, session monitoring, double-tap,
; shell execution, and path normalization.

; ── Notification ToolTip Manager ──
; Uses a dedicated, reusable function object to clear tooltips without timer collision.
Notify(msg, durationMs := 2000) {
    static clearFn := () => ToolTip()
    SetTimer(clearFn, 0)  ; Cancel any pending clear
    ToolTip(msg)
    if durationMs > 0
        SetTimer(clearFn, -Abs(durationMs))
}

; ── Workstation Session Monitor (Win+L / Secure Desktop) ──
; Event-driven: Windows raises WM_WTSSESSION_CHANGE (0x2B1) on lock/unlock.
; Polling WTSConnectState is unreliable (often stays WTSActive on Win+L).
SessionLocked := false
SessionLockCallbacks := []

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
    global SessionLocked, SessionLockCallbacks
    if (wParam = 0x7)        ; WTS_SESSION_LOCK
        SessionLocked := true
    else if (wParam = 0x8)   ; WTS_SESSION_UNLOCK
        SessionLocked := false
    else
        return

    for cb in SessionLockCallbacks {
        try cb(SessionLocked)
    }
}

if !RegisterSessionMonitor()
    Notify("Session monitor failed to register", 3000)

; ── Double-Tap State Machine ──
; Pending taps per key (keyName -> last press tick) + last key that engaged DoubleTap.
DoubleTapTaps    := Map()
DoubleTapLastKey := ""

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

; ── Shell Execution (De-elevation) ──
; Run a program at user (non-elevated) integrity level via the desktop shell.
; Source: AutoHotkeyUX/inc/ShellRun.ahk (Lexikos), AHK v2 port.
ShellRun(filePath, arguments?, directory?, operation?, show?) {
    static VT_UI4 := 0x13, SWC_DESKTOP := ComValue(VT_UI4, 0x8)
    ComObject("Shell.Application").Windows.Item(SWC_DESKTOP).Document.Application
        .ShellExecute(filePath, arguments?, directory?, operation?, show?)
}

; ── Path Normalization Helpers ──
; Expand a leading "~" (pwsh-style home) to the user profile directory.
; Accepts "~/path", "~\" or bare "~". Other input is returned unchanged.
ExpandTilde(path) {
    if path = "~"
        return EnvGet("USERPROFILE")
    if RegExMatch(path, '^~[\\/]')
        return StrReplace(EnvGet("USERPROFILE") . SubStr(path, 2), "/", "\")
    return path
}

; Extract and sanitize a file or directory path from the clipboard.
; Strips leading/trailing whitespace, quotes, file:/// scheme, expands tildes,
; and normalizes slashes to Windows backslashes.
GetClipboardPath(&outPath) {
    raw := Trim(A_Clipboard, " `t`r`n")
    raw := Trim(raw, "`"'")
    if RegExMatch(raw, '^file:///')
        raw := StrReplace(SubStr(raw, 9), "/", "\")
    raw := ExpandTilde(raw)
    raw := StrReplace(raw, "/", "\")
    outPath := raw
    return outPath != ""
}

SerialConnected := false

; ═══ SERIAL BUTTON GRID (HARDWARE) ═══════════════════════════════════════════

; --- Native Windows Serial Connection ---
hCom := 0
try {
    hCom := DllCall("CreateFile"
        , "Str", "\\.\" . ComPort
        , "UInt", 0xC0000000  ; GENERIC_READ | GENERIC_WRITE
        , "UInt", 0           ; No sharing
        , "Ptr", 0            ; Security attributes
        , "UInt", 3           ; OPEN_EXISTING
        , "UInt", 0           ; Flags
        , "Ptr", 0, "Ptr")
} catch as err {
    hCom := 0
}

if (hCom == -1 || hCom == 0) {
    Notify(ComPort . " not available — serial buttons disabled", 3000)
    hCom := 0
} else {
    try {
        ; Build DCB safely using Windows API parser string
        DCB := Buffer(28, 0)       ; DCB struct size is 28 bytes
        NumPut("UInt", 28, DCB, 0) ; Set DCBlength

        if !DllCall("GetCommState", "Ptr", hCom, "Ptr", DCB)
            throw Error("GetCommState failed")

        ; Use BuildCommDCB to avoid manual struct bitfield offset corruption
        if !DllCall("BuildCommDCBW", "Str", "baud=" . BaudRate . " parity=N data=8 stop=1", "Ptr", DCB)
            throw Error("BuildCommDCB failed")

        if !DllCall("SetCommState", "Ptr", hCom, "Ptr", DCB)
            throw Error("SetCommState failed")

        ; Toggle DTR & RTS lines to wake up Arduino Nano USB-Serial chip
        SETRTS := 3, SETDTR := 5
        DllCall("EscapeCommFunction", "Ptr", hCom, "UInt", SETDTR)
        DllCall("EscapeCommFunction", "Ptr", hCom, "UInt", SETRTS)

        ; Set Timeouts (non-blocking read)
        Timeouts := Buffer(20, 0)
        NumPut("UInt", 0xFFFFFFFF, Timeouts, 0) ; UInt mapping for MAXDWORD
        DllCall("SetCommTimeouts", "Ptr", hCom, "Ptr", Timeouts)

        OnExit((*) => (hCom ? DllCall("CloseHandle", "Ptr", hCom) : 0))
        SerialConnected := true
    } catch as err {
        Notify("Serial config failed (" . err.Message . ") — buttons disabled", 3000)
        DllCall("CloseHandle", "Ptr", hCom)
        hCom := 0
    }
}

ReadBuffer := ""

; Start polling serial input after Arduino boot delay
if SerialConnected
    SetTimer(StartSerialPolling, -2000)

StartSerialPolling() {
    global hCom
    if hCom
        SetTimer(ReadSerial, 30)
}

CloseSerialPort(reason := "") {
    global hCom, SerialConnected
    SetTimer(ReadSerial, 0)
    if hCom {
        DllCall("CloseHandle", "Ptr", hCom)
        hCom := 0
    }
    SerialConnected := false
    if reason != ""
        Notify("Serial disconnected: " . reason, 3000)
}

ReadSerial() {
    global hCom, ReadBuffer, SessionLocked
    if !hCom
        return
    try {
        buf := Buffer(64, 0)
        bytesRead := 0

        ; Pass buf.Ptr to Write/Read raw memory correctly
        if DllCall("ReadFile", "Ptr", hCom, "Ptr", buf.Ptr, "UInt", 64, "UInt*", &bytesRead, "Ptr", 0) {
            if bytesRead > 0 {
                ReadBuffer .= StrGet(buf.Ptr, bytesRead, "UTF-8")

                ; Prevent unbounded buffer growth on noisy serial line
                if StrLen(ReadBuffer) > 2048
                    ReadBuffer := SubStr(ReadBuffer, -1024)

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
        } else {
            ; ReadFile returned 0: detect disconnect / device unplugged
            errCode := DllCall("GetLastError", "UInt")
            if (errCode == 5 || errCode == 22 || errCode == 1167) ; ERROR_ACCESS_DENIED, ERROR_BAD_COMMAND, ERROR_DEVICE_NOT_CONNECTED
                CloseSerialPort("Device unplugged or lost")
        }
    } catch {
        CloseSerialPort("Read exception")
    }
}

; ═══ MACRO DISPATCH TABLE ═════════════════════════════════════════════════════
; Dispatches ButtonGrid commands (L1_K_* and L2_K_*) for both the serial hardware
; pad and the numpad grid mirror.

DispatchMacro(cmd) {
    global DoubleTapTaps, DoubleTapLastKey
    if (DoubleTapLastKey != cmd)
        DoubleTapTaps.Clear()   ; any other key cancels pending taps

    switch cmd {
        ; ═══ LAYER 1 ═════════════════════════════
        case "L1_K_01": 
            Notify("Launching Sublime Text...")
            LaunchAndFocus(APP_SUBLIME)

        case "L1_K_02": 
            Notify("L1__B_02")

        case "L1_K_03":
            if ProcessExist("krita.exe") {
                Notify("Double-tap to paste image in BeeRef")
                DoubleTap("L1_K_03", () => LaunchBeeRefAndPasteImage())
            } else {
                Notify("Launching Krita...")
                LaunchAndFocus(APP_KRITA)
            }

        case "L1_K_04":
            GetClipboardPath(&raw)
            if (raw && RegExMatch(raw, 'i)\.(glb|gltf|obj)$', &m) && FileExist(raw)) {
                scriptPath := A_ScriptDir . "\src\blender_import.py"
                Notify("Opening " raw " in Blender...")
                LaunchAndFocus(APP_BLENDER, '--python "' scriptPath '" -- "' raw '"')
            } else {
                Notify("Launching Blender...")
                LaunchAndFocus(APP_BLENDER)
            }

        case "L1_K_05": 
            Notify("L1__B_05")

        case "L1_K_06":
            Notify("Launching Telegram...")
            LaunchAndFocus(APP_TELEGRAM)

        case "L1_K_07": 
            Notify("L1__B_07")

        case "L1_K_08": 
            Notify("L1__B_08")

        case "L1_K_09": 
            Notify("L1__B_09")

        ; KEY 10 is reserved for hardware / virtual layer switching

        ; L1_K_11: open opencode in Windows Terminal at the clipboard path
        case "L1_K_11":
            GetClipboardPath(&raw)
            if !raw {
                Notify("Clipboard is empty — copy a path first")
            } else if DirExist(raw) {
                LaunchOpencode(raw)
            } else if FileExist(raw) {
                SplitPath(raw, , &dir)
                LaunchOpencode(dir)
            } else {
                Notify("Not a valid path: " raw)
            }

        case "L1_K_12":
            DoubleTap("L1_K_12", () => Send("^#{x}"))

        ; ═══ LAYER 2 ═════════════════════════════
        case "L2_K_01": Notify("L2__B_01")
        case "L2_K_02": Notify("L2__B_02")
        case "L2_K_03": Notify("L2__B_03")
        case "L2_K_04": Notify("L2__B_04")
        case "L2_K_05": Notify("L2__B_05")
        case "L2_K_06": Notify("L2__B_06")
        case "L2_K_07": Notify("L2__B_07")
        case "L2_K_08": Send("^#{Left}")    ; Ctrl+Win+Left → previous desktop
        case "L2_K_09": Send("^#{Right}")   ; Ctrl+Win+Right → next desktop
        ; KEY 10 is reserved for hardware layer switching
        case "L2_K_11": Notify("L2__B_11")
        case "L2_K_12": Notify("L2__B_12")
    }
}

; Launch BeeRef and let it paste the clipboard image itself via --paste.
; The GUI window belongs to the child pythonw.exe process (pip distlib
; launcher spawns it and waits), so match that, NOT beeref.exe.
LaunchBeeRefAndPasteImage() {
    LaunchAndFocus(APP_BEEREF, '--paste', 'pythonw.exe')
}

; ═══ SYSTEM SHORTCUTS ═════════════════════════════════════════════════════════

; Ctrl+Alt+Win+ñ — Reload the script via the upkey shell command
^#!ñ::
{
    Notify("Reloading script via upkey...", 1000)
    Run('pwsh.exe -NoLogo -Command ". $PROFILE; upkey"')
}

; Ctrl+Alt+Win+p — Open the splice sources folder (this file is generated by merge.py)
^#!p::
{
    LaunchAndFocus(APP_EXPLORER, '"' A_ScriptDir '\src"')
}

; Win+E — Open Downloads in File Explorer
#e::
{
    LaunchAndFocus(APP_EXPLORER, '"' DIR_DOWNLOADS '"')
}

; Ctrl+Win+T — Launch Windows Terminal
^#t:: {
    LaunchAndFocus(APP_WT, "", "WindowsTerminal.exe")
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
    if !(ProcessExist("overwatch.exe") && WinActive("ahk_exe overwatch.exe")) {
        Notify("Volume: " . Round(SoundGetVolume()) . "%", 1000)
    }
}

; Ctrl+Alt+Win+Down — Volume down by 1
^#!Down:: {
    SoundSetVolume("-1")
    if !(ProcessExist("overwatch.exe") && WinActive("ahk_exe overwatch.exe")) {
        Notify("Volume: " . Round(SoundGetVolume()) . "%", 1000)
    }
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

$!F2::Send("3")

; Shift+F10 sends )
$+F10::Send(")")

$!F10::Send("9")

; Alt+4 sends # (hash)
!4::SendText("#")

; ═══ NUMPAD GRID (AutoHotInterception) ═════════════════════════════════════════
; The DEFAULT (built-in) keyboard's numpad becomes a ButtonGrid macro pad, but
; only while the SECONDARY keyboard (VID 0x248A / PID 0x8367) is connected.
; When the secondary is unplugged, the numpad reverts to normal typing.
;
; The 12 mapped keys are blocked at the driver level (Interception) so nothing
; leaks into the focused app — exactly like the hardware ButtonGrid, which sends
; commands rather than keystrokes.
;
; Mapping (numpad key -> grid K):
;   +  -> K1       7 -> K4   4 -> K7   1 -> K10 (layer toggle)
;   -  -> K2       8 -> K5   5 -> K8   2 -> K11
;   BloqNum -> K3  9 -> K6   6 -> K9   3 -> K12
;   / * 0 Enter are NOT mapped and keep normal behavior.

#Include "%A_ScriptDir%\lib\numpad_grid\AutoHotInterception.ahk"

; scan code -> K number (10 = layer switch)
NUMGRID_MAP := Map(
    GetKeySC("NumpadAdd"),  1,
    GetKeySC("NumpadSub"),  2,
    GetKeySC("NumLock"),    3,
    GetKeySC("Numpad7"),    4,
    GetKeySC("Numpad8"),    5,
    GetKeySC("Numpad9"),    6,
    GetKeySC("Numpad4"),    7,
    GetKeySC("Numpad5"),    8,
    GetKeySC("Numpad6"),    9,
    GetKeySC("Numpad1"),    10,
    GetKeySC("Numpad2"),    11,
    GetKeySC("Numpad3"),    12,
)

; ── State ──────────────────────────────────────────────────────────────────────
MiniGridLayer      := 0          ; 0 = L1, 1 = L2
MiniGridArmed      := false      ; secondary present AND subscribed
MiniGridSubscribed := false
MiniGridIds        := []         ; resolved AHI ids for the default keyboard

; ═══════════════════════════════════════════════════════════════════════════════
; ═══ INIT ═════════════════════════════════════════════════════════════════════
; ═══════════════════════════════════════════════════════════════════════════════

try {
    MiniGridAHI := AutoHotInterception()
} catch as err {
    MiniGridAHI := 0
    Notify("AutoHotInterception unavailable — numpad grid disabled (" err.Message ")", 3000)
}

if MiniGridAHI {
    ; Resolve default keyboard ids from the device list by handle.
    try {
        devs := MiniGridAHI.GetDeviceList()
        for id, d in devs {
            if d.IsMouse
                continue
            for h in NUMGRID_DEFAULT_HANDLES {
                if (d.Handle = h)
                    MiniGridIds.Push(id)
            }
        }
    } catch {
        MiniGridIds := []
    }

    if MiniGridIds.Length = 0 {
        Notify("Numpad grid: default keyboard handle not found — grid disabled", 3000)
        MiniGridAHI := 0
    } else {
        SessionLockCallbacks.Push((*) => MiniGridSyncState())
        ; Listen for USB plug/unplug events
        OnMessage(0x0219, OnMiniGridDeviceChange)
        ; Background safety poll (every 5 seconds)
        SetTimer CheckMiniGridSecondary, 5000
        MiniGridSyncState()   ; initial sync
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; ═══ WATCHDOG: arm/disable on secondary keyboard connect or session lock/unlock 
; ═══════════════════════════════════════════════════════════════════════════════

OnMiniGridDeviceChange(wParam, lParam, msg, hwnd) {
    ; DBT_DEVNODES_CHANGED = 0x0007
    if (wParam = 7)
        SetTimer(MiniGridSyncState, -200) ; debounced sync
}

CheckMiniGridSecondary() {
    MiniGridSyncState()
}

MiniGridSyncState() {
    global MiniGridAHI, MiniGridArmed, MiniGridSubscribed, SessionLocked
    if !MiniGridAHI
        return
    shouldBeActive := !SessionLocked && MiniGridSecondaryPresent()
    if shouldBeActive && !MiniGridSubscribed {
        if MiniGridSubscribe() {
            MiniGridArmed := true
            MiniGridSubscribed := true
            if !SessionLocked {
                Notify("Numpad grid armed (secondary connected)", 2000)
            }
        }
    } else if !shouldBeActive && MiniGridSubscribed {
        MiniGridUnsubscribe()
        MiniGridArmed := false
        MiniGridSubscribed := false
        if !SessionLocked {
            Notify("Numpad grid disabled (secondary removed)", 2000)
        }
    }
}

MiniGridSecondaryPresent() {
    global MiniGridAHI, NUMGRID_SECONDARY_VID, NUMGRID_SECONDARY_PID
    try {
        devs := MiniGridAHI.GetDeviceList()
        for id, d in devs {
            if !d.IsMouse && d.VID = NUMGRID_SECONDARY_VID && d.PID = NUMGRID_SECONDARY_PID
                return true
        }
    }
    return false
}

MiniGridSubscribe() {
    global MiniGridAHI, MiniGridIds, NUMGRID_MAP
    for kbId in MiniGridIds {
        for code, k in NUMGRID_MAP {
            try {
                MiniGridAHI.SubscribeKey(kbId, code, 1, MiniGridDispatch.Bind(k))
            } catch as err {
                Notify("Numpad grid subscribe failed (" err.Message ")", 3000)
                return false
            }
        }
    }
    return true
}

MiniGridUnsubscribe() {
    global MiniGridAHI, MiniGridIds, NUMGRID_MAP
    for kbId in MiniGridIds {
        for code, k in NUMGRID_MAP {
            try
                MiniGridAHI.UnsubscribeKey(kbId, code)
        }
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; ═══ DISPATCH ═════════════════════════════════════════════════════════════════
; ═══════════════════════════════════════════════════════════════════════════════

; Bound once per subscribed key with its K number captured: MiniGridDispatch(K, state)
MiniGridDispatch(K, state) {
    global MiniGridArmed, MiniGridLayer, SessionLocked
    if state != 1            ; only act on key-down
        return
    if !MiniGridArmed
        return
    if SessionLocked         ; match serial ButtonGrid gating
        return
    if K = 10 {              ; layer switch
        MiniGridLayer := !MiniGridLayer
        Notify("Numpad grid layer: L" (MiniGridLayer ? "2" : "1"), 1500)
    } else {
        ; Reuse DispatchMacro with a synthesized layer-aware grid command, so the
        ; numpad drives the exact same actions as the hardware ButtonGrid.
        DispatchMacro((MiniGridLayer ? "L2" : "L1") . "_K_" . Format("{:02}", K))
    }
}

; ═══ TERMINAL OPACITY ═════════════════════════════════════════════════════════
; Alt+F1 toggles Windows Terminal opacity by rewriting its settings.json.
; Cycles: 90% → 65% → whatever was set → 90%.

#HotIf WinActive("ahk_exe WindowsTerminal.exe")
!F1:: {
    if !FileExist(TERMINAL_SETTINGS_PATH) {
        return
    }

    try {
        fileContent := FileRead(TERMINAL_SETTINGS_PATH)

        if RegExMatch(fileContent, '"opacity":\s*' . OPACITY_HIGH) {
            fileContent := RegExReplace(fileContent, '"opacity":\s*' . OPACITY_HIGH, '"opacity": ' . OPACITY_LOW)
        } else if RegExMatch(fileContent, '"opacity":\s*' . OPACITY_LOW) {
            fileContent := RegExReplace(fileContent, '"opacity":\s*' . OPACITY_LOW, '"opacity": ' . OPACITY_HIGH)
        } else {
            fileContent := RegExReplace(fileContent, '"opacity":\s*\d+', '"opacity": ' . OPACITY_HIGH)
        }

        FileObj := FileOpen(TERMINAL_SETTINGS_PATH, "w", "UTF-8")
        FileObj.Write(fileContent)
        FileObj.Close()
    } catch as err {
        Notify("Failed to write Terminal settings: " . err.Message, 3000)
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

; Bring `hwnd` to the foreground, working around the Windows foreground-lock.
; A plain WinActivate is denied when the script isn't the foreground process and
; has no recent user input — the serial button grid is timer-driven, so the OS
; never grants the script foreground rights. The chain escalates until the
; window is actually active. The script is elevated, so every step is
; UIPI-permitted against the non-elevated launched apps.
; Best-effort: a launched app's transient window (splash/loader) may close at
; any moment, so every step tolerates a vanished window and returns false.
ForceFocus(hwnd) {
    try {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false

        ; Step 1: plain activation — enough when the script has input eligibility.
        if DllCall("IsIconic", "Ptr", hwnd)
            WinRestore("ahk_id " hwnd)
        WinActivate("ahk_id " hwnd)
        if WinWaitActive("ahk_id " hwnd, , 1)
            return true

        ; Step 2: attach our thread to the foreground thread's input queue so the
        ; system treats us as the foreground process, then force the target up.
        fg := DllCall("GetForegroundWindow", "Ptr")
        if fg {
            fgTid := DllCall("GetWindowThreadProcessId", "Ptr", fg, "Ptr", 0)
            myTid := DllCall("GetCurrentThreadId")
            if fgTid && DllCall("AttachThreadInput", "UInt", fgTid, "UInt", myTid, "Int", 1) {
                DllCall("BringWindowToTop", "Ptr", hwnd)
                DllCall("SetForegroundWindow", "Ptr", hwnd)
                DllCall("AttachThreadInput", "UInt", fgTid, "UInt", myTid, "Int", 0)
                if WinWaitActive("ahk_id " hwnd, , 1)
                    return true
            }
        }

        ; Step 3: release the foreground lock with an inert keypress, then retry.
        SendInput("{vk07}")
        WinActivate("ahk_id " hwnd)
        return WinWaitActive("ahk_id " hwnd, , 1)
    } catch {
        return false
    }
}

; Find a newly spawned window matching `criteria` that was not in `beforeList`,
; or fall back to the first existing window in `beforeList`.
FindTargetWindow(criteria, beforeList) {
    for w in WinGetList(criteria) {
        wasOpen := false
        for b in beforeList {
            if (w = b) {
                wasOpen := true
                break
            }
        }
        if !wasOpen
            return w ; Brand-new window
    }
    return (beforeList.Length > 0 ? beforeList[1] : 0)
}

; Launch an app de-elevated via the desktop shell, wait for its window, and
; force it to the foreground. exeName defaults to the launch file's name; pass
; it explicitly when the real window belongs to a different process.
LaunchAndFocus(filePath, arguments?, exeName := "") {
    if exeName = ""
        SplitPath(filePath, &exeName)
    before := WinGetList("ahk_exe " exeName)

    ShellRun(filePath, arguments?)

    if !WinWait("ahk_exe " exeName, , 10)
        return false

    Sleep(300)  ; let the window finish materializing before activating

    target := FindTargetWindow("ahk_exe " exeName, before)
    if target && ForceFocus(target)
        return true

    ; The picked window closed mid-focus (a splash/loader that hands off to the
    ; real window). Give the app a moment to settle, then focus its main window.
    Sleep(1000)
    wins := WinGetList("ahk_exe " exeName)
    if wins.Length > 0
        return ForceFocus(wins[1])
    return false
}

; Launch opencode in Windows Terminal at the given directory, then size the
; terminal window to the same dimensions Win+F1 uses.
; wt.exe is launched de-elevated so it can attach to existing (non-elevated)
; terminals as a new tab, or spawn a fresh window when none are running.
LaunchOpencode(dir) {
    ; A trailing "\" would be eaten by the closing quote of the wt -d argument
    ; (CommandLineToArgvW turns `"C:\path\"` into `C:\path"`), so drop it first.
    dir := RegExReplace(dir, '(?<!:)[\\/]+$')
    before := WinGetList("ahk_class CASCADIA_HOSTING_WINDOW_CLASS")

    ShellRun(APP_WT, '-d "' dir '" pwsh.exe -NoExit -Command "opencode"')

    if WinWait("ahk_class CASCADIA_HOSTING_WINDOW_CLASS", , 5) {
        Sleep(400)
        target := FindTargetWindow("ahk_class CASCADIA_HOSTING_WINDOW_CLASS", before)

        if target {
            ForceFocus(target)
            ResizeTerminal(target)
        }
    }
}

; Query MONITORINFO for the monitor containing `hwnd`.
GetMonitorInfoForWindow(hwnd, &mi) {
    hMon := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 0x2, "Ptr") ; MONITOR_DEFAULTTONEAREST
    if !hMon
        return false

    mi := Buffer(40)                           ; MONITORINFO
    NumPut("UInt", mi.Size, mi, 0)             ; cbSize
    return DllCall("GetMonitorInfo", "Ptr", hMon, "Ptr", mi)
}

; Get the work area of the monitor containing `hwnd` (nearest if off-screen).
MonitorWorkArea(hwnd, &left, &top, &right, &bottom) {
    if !GetMonitorInfoForWindow(hwnd, &mi)
        return false

    left   := NumGet(mi, 20, "Int")            ; rcWork.left
    top    := NumGet(mi, 24, "Int")            ; rcWork.top
    right  := NumGet(mi, 28, "Int")            ; rcWork.right
    bottom := NumGet(mi, 32, "Int")            ; rcWork.bottom
    return true
}

; True if the monitor containing `hwnd` has the given physical resolution
; (rcMonitor, not rcWork — unaffected by DPI scaling / taskbar placement).
MonitorPhysicalSize(hwnd, width, height) {
    if !GetMonitorInfoForWindow(hwnd, &mi)
        return false

    ; MONITORINFO: cbSize(0) | rcMonitor l,t,r,b (4,8,12,16) | rcWork l,t,r,b (20,24,28,32)
    monWidth  := NumGet(mi, 12, "Int") - NumGet(mi, 4, "Int")    ; rcMonitor.right - rcMonitor.left
    monHeight := NumGet(mi, 16, "Int") - NumGet(mi, 8, "Int")    ; rcMonitor.bottom - rcMonitor.top
    return (monWidth = width && monHeight = height)
}

; Win+F1: Snap Task Manager to the right 58% of whichever monitor it's on.
; On a 1920x1080 monitor it aligns flush to the top-right; elsewhere it keeps
; the tuned offsets from the original Monitor 1 behavior.
#HotIf WinActive("ahk_class TaskManagerWindow")
#F1:: {
    activeHWnd := WinExist("A")

    try {
        if !GetMonitorInfoForWindow(activeHWnd, &mi)
            throw

        left   := NumGet(mi, 20, "Int")            ; rcWork.left
        top    := NumGet(mi, 24, "Int")            ; rcWork.top
        right  := NumGet(mi, 28, "Int")            ; rcWork.right
        bottom := NumGet(mi, 32, "Int")            ; rcWork.bottom

        monitorWidth  := right - left
        monitorHeight := bottom - top

        targetWidth  := monitorWidth * TASKMANAGER_WIDTH_PCT
        targetHeight := monitorHeight + 9

        monPhysW := NumGet(mi, 12, "Int") - NumGet(mi, 4, "Int")
        monPhysH := NumGet(mi, 16, "Int") - NumGet(mi, 8, "Int")

        if (monPhysW = 1920 && monPhysH = 1080) {
            ; 1920x1080 screen: flush top-right, 41% width, 50% height, nudged 9px toward the right
            targetWidth  := monitorWidth * TASKMANAGER_1080P_WIDTH_PCT
            targetHeight := monitorHeight * TASKMANAGER_1080P_HEIGHT_PCT
            targetX := right - targetWidth + TASKMANAGER_1080P_X_OFFSET
            targetY := top + TASKMANAGER_1080P_Y_OFFSET
        } else {
            ; Other screens: keep the tuned offsets (flush right +7, top -1)
            targetX := right - targetWidth + 7
            targetY := top - 1
        }

        WinMove(targetX, targetY, targetWidth, targetHeight, activeHWnd)
    } catch {
        Notify("Failed to detect the Task Manager's monitor.", 2000)
    }
}
#HotIf  ; ── end context ──

; Win+F1: Resize Microsoft Edge to a fraction of the work area, left-aligned.
#HotIf WinActive("ahk_exe msedge.exe")
#F1:: {
    activeHwnd := WinExist("A")
    if !activeHwnd
        return

    ; Edge is per-monitor-DPI-aware; AHK v2 is not. On this mixed-scale setup
    ; (left monitor 200%, primary 100%) AHK's coordinates are DPI-virtualized,
    ; so WinMove sizes land wrong. Switch this thread to Per-Monitor v2 so all
    ; coordinates are physical pixels, matching Edge, then restore.
    origContext := DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
    try {
        ; A maximized window ignores WinMove, so restore it first.
        if DllCall("IsZoomed", "Ptr", activeHwnd)
            WinRestore("ahk_id " activeHwnd)

        if MonitorWorkArea(activeHwnd, &left, &top, &right, &bottom) {
            width  := EDGE_WIDTH_PX + EDGE_SIZE_W_OFFSET
            height := (bottom - top) * EDGE_HEIGHT_PCT + EDGE_SIZE_H_OFFSET
            WinMove(left + EDGE_X_OFFSET + EDGE_POS_X_OFFSET,
                top + EDGE_POS_Y_OFFSET, width, height, activeHwnd)
        } else {
            Notify("Failed to detect monitor.", 2000)
        }
    } catch {
    }
    if origContext
        DllCall("SetThreadDpiAwarenessContext", "Ptr", origContext, "Ptr")
}
#HotIf  ; ── end context ──

; Win+F1 fallback: swallow everywhere else so Windows Help never opens.
; The context variants above take precedence when their #HotIf matches.
#F1:: {
    Notify("Win+F1 — no action", 500)
}

; ═══ DEBUG TOOLS ══════════════════════════════════════════════════════════════

; Ctrl+Alt+Shift+Win+. — Show active window info (title, class, process, position, size)
^!+#.:: {
    activeHWnd := WinExist("A")
    if !activeHWnd {
        Notify("No active window detected.", 2000)
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
