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
