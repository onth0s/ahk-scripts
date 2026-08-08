
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
