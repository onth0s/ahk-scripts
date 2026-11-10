
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
