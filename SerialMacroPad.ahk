#Requires AutoHotkey v2.0
#SingleInstance Force

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

; --- YOUR MACRO MAPPINGS ---
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
        case "KEY_12": MsgBox("Macro Pad Connected & Triggered Successfully!")
    }
}