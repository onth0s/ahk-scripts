
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

    target := 0
    for w in WinGetList("ahk_exe " exeName) {
        wasOpen := false
        for b in before {
            if w = b {
                wasOpen := true
                break
            }
        }
        if !wasOpen {
            target := w            ; a brand-new window was created
            break
        }
    }
    if !target && before.Length > 0
        target := before[1]        ; single-instance app → activate existing window

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

; Expand a leading "~" (pwsh-style home) to the user profile directory.
; Accepts "~/path", "~\" or bare "~". Other input is returned unchanged.
; Forward slashes from "~/path" are normalized to backslashes for Windows.
ExpandTilde(path) {
    if path = "~"
        return EnvGet("USERPROFILE")
    if RegExMatch(path, '^~[\\/]')
        return StrReplace(EnvGet("USERPROFILE") . SubStr(path, 2), "/", "\")
    return path
}

; Launch opencode in Windows Terminal at the given directory, then size the
; terminal window to the same dimensions Win+F1 uses.
; wt.exe is launched de-elevated so it can attach to existing (non-elevated)
; terminals as a new tab, or spawn a fresh window when none are running.
LaunchOpencode(dir) {
    ; A trailing "\" would be eaten by the closing quote of the wt -d argument
    ; (CommandLineToArgvW turns `"C:\path\"` into `C:\path"`), so drop it first.
    dir := RegExReplace(dir, '(?<!:)[\\/]+$')
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
            ForceFocus(target)
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
            ToolTip("Failed to detect monitor.")
            SetTimer(() => ToolTip(), -2000)
        }
    } catch {
    }
    if origContext
        DllCall("SetThreadDpiAwarenessContext", "Ptr", origContext, "Ptr")
}
#HotIf  ; ── end context ──

; Get the work area of the monitor containing `hwnd` (nearest if off-screen).
; AHK v2 has no built-in window→monitor helper; MonitorGetWorkArea only takes a
; monitor number, so resolve the monitor via MonitorFromWindow + GetMonitorInfo.
MonitorWorkArea(hwnd, &left, &top, &right, &bottom) {
    hMon := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 0x2, "Ptr") ; MONITOR_DEFAULTTONEAREST
    if !hMon
        return false

    mi := Buffer(40)                           ; MONITORINFO
    NumPut("UInt", mi.Size, mi, 0)             ; cbSize
    if !DllCall("GetMonitorInfo", "Ptr", hMon, "Ptr", mi)
        return false

    left   := NumGet(mi, 20, "Int")            ; rcWork.left
    top    := NumGet(mi, 24, "Int")            ; rcWork.top
    right  := NumGet(mi, 28, "Int")            ; rcWork.right
    bottom := NumGet(mi, 32, "Int")            ; rcWork.bottom
    return true
}
