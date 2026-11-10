
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
