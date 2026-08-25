
ComPort := "COM5"   ; Your Nano's COM port
BaudRate := 9600
SerialConnected := false

; ═══ BUTTON GRID ═════════════════════════════════════════════════════════
; ═══ BUTTON GRID ═════════════════════════════════════════════════════════
; ═══ BUTTON GRID ═════════════════════════════════════════════════════════

; --- NATIVE WINDOWS SERIAL CONNECTION ---
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
    ToolTip(ComPort . " not available — serial buttons disabled")
    SetTimer(() => ToolTip(), -3000)
    hCom := 0
} else {
    try {
        ; CRITICAL FIX: Give the Arduino 2 seconds to reboot after the DTR toggle
        Sleep(2000)

        ; Build DCB safely using Windows API parser string
        DCB := Buffer(28, 0)       ; FIX: DCB struct size is exactly 28 bytes
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
        NumPut("UInt", 0xFFFFFFFF, Timeouts, 0) ; FIX: Safer UInt mapping for MAXDWORD
        DllCall("SetCommTimeouts", "Ptr", hCom, "Ptr", Timeouts)

        OnExit((*) => DllCall("CloseHandle", "Ptr", hCom))
        SerialConnected := true
    } catch as err {
        ToolTip("Serial config failed (" . err.Message . ") — buttons disabled")
        SetTimer(() => ToolTip(), -3000)
        DllCall("CloseHandle", "Ptr", hCom)
        hCom := 0
    }
}

ReadBuffer := ""

if SerialConnected
    SetTimer ReadSerial, 30

ReadSerial() {
    global hCom, ReadBuffer, SessionLocked
    if !hCom
        return
    try {
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
            LaunchAndFocus('C:\Program Files\Sublime Text\sublime.exe')
        case "L1_K_02": ToolTip("L1__B_02")
        case "L1_K_03":
            if ProcessExist("krita.exe") {
                ToolTip("Double-tap to paste image in BeeRef")
                DoubleTap("L1_K_03", () => LaunchBeeRefAndPasteImage())
            } else {
                ToolTip("Launching Krita...")
                LaunchAndFocus('C:\Program Files\Krita (x64)\bin\krita.exe')
            }
        case "L1_K_04": ToolTip("L1__B_04")
        case "L1_K_05": ToolTip("L1__B_05")
        case "L1_K_06":
            ToolTip("Launching Telegram...")
            LaunchAndFocus('C:\Users\Leonardo\AppData\Roaming\Telegram Desktop\Telegram.exe')
        case "L1_K_07": ToolTip("L1__B_07")
        case "L1_K_08": ToolTip("L1__B_08")
        case "L1_K_09": ToolTip("L1__B_09")
        ; KEY 10 is reserved for hardware layer switching
        ; L1_K_11: open opencode in Windows Terminal at the clipboard path
        case "L1_K_11":
            raw := Trim(A_Clipboard, " `t`r`n")
            raw := Trim(raw, "`"'")               ; strip surrounding quotes of either type
            if RegExMatch(raw, '^file:///')
                raw := StrReplace(SubStr(raw, 9), "/", "\")
            raw := ExpandTilde(raw)
            raw := StrReplace(raw, "/", "\")       ; normalize remaining separators

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
        case "L2_K_07": Send("^#{Left}")    ; Ctrl+Win+Left → previous desktop
        case "L2_K_08": ToolTip("L2__B_08")
        case "L2_K_09": Send("^#{Right}")   ; Ctrl+Win+Right → next desktop
        ; KEY 10 is reserved for hardware layer switching
        case "L2_K_11": ToolTip("L2__B_11")
        case "L2_K_12": ToolTip("L2__B_12")
    }
    
    ; Clear the tooltip automatically after 1 second
    SetTimer(() => ToolTip(), -2000) 
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
    LaunchAndFocus('C:\Users\Leonardo\001\00__DEV\BeeRef\.venv\Scripts\beeref.exe', '--paste', 'pythonw.exe')
}

; ═══ BUTTON GRID ═════════════════════════════════════════════════════════
; ═══ BUTTON GRID ═════════════════════════════════════════════════════════
; ═══ BUTTON GRID ═════════════════════════════════════════════════════════

