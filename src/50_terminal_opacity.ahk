
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
