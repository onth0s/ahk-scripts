# AGENTS.md

## AutoHotkey v2 Gotchas

### `A_LocalAppData` (and possibly other `A_*` built-in variables) — UNSET ERROR

**Symptom:** `Error: This global variable has not been assigned a value. Specifically: A_LocalAppData`

**Cause:** `#Warn VarUnset, Off` does NOT suppress this error for built-in `A_*` variables.
This is a known AHK v2 behavior — the `#Warn` directive is insufficient.

**Fix:** Never use `A_LocalAppData` directly. Use `EnvGet` instead:

```ahk
# WRONG — will throw "unset variable" error:
TERMINAL_SETTINGS_PATH := A_LocalAppData . "\Some\Path"

# CORRECT — EnvGet reads the env var directly:
TERMINAL_SETTINGS_PATH := EnvGet("LOCALAPPDATA") . "\Some\Path"
```

**Additional notes on `EnvGet` in AHK v2:**
- `EnvGet` takes ONE parameter (the env var name) and RETURNS the value.
- Do NOT use `&outputVar` syntax — that is wrong for `EnvGet`.
- Correct: `myVar := EnvGet("VARIABLE_NAME")`
- Wrong: `EnvGet(&myVar, "VARIABLE_NAME")`

### `#Warn VarUnset, Off` — Does Not Suppress All Unset Errors

**Do not rely on `#Warn VarUnset, Off`** to handle built-in variables. It only suppresses
user-defined variable warnings. Built-in `A_*` variables can still throw runtime errors
in certain contexts despite this directive being present.

### `global` Keyword in Auto-Execute Section

Variables assigned in the auto-execute section (top level, outside any function/hotkey)
are implicitly global. Explicit `global` keyword is optional but harmless there.
Hotkey handlers and functions can read these variables without re-declaring them as
`global` inside the handler body.

### `Clipboard` Does Not Exist in AHK v2 — Use `A_Clipboard`

**Symptom:** `Error: This local/global variable has not been assigned a value. Specifically: Clipboard`

**Cause:** v1's `Clipboard` was renamed in v2 to `A_Clipboard`. Referencing `Clipboard`
(and other v1-only names like `A_LocalAppData`) throws an unset error — `#Warn VarUnset, Off`
does NOT help, and a `global Clipboard` declaration just promotes the empty variable.

**Fix:** Use the v2 built-in `A_Clipboard`:

```ahk
raw := Trim(A_Clipboard, " `t`r`n")   ; A_* built-ins work inside functions — no `global` needed
```

### AHK Version

This project requires **AutoHotkey v2.0** (`#Requires AutoHotkey v2.0`).
Always write AHK v2 syntax:
- Functions use `&` for by-reference output params (e.g., `WinGetPos(&x, &y, &w, &h)`)
- `EnvGet` is an exception — it returns the value directly, no `&`
- `try/catch as err` syntax (not `catch e`)
- Block syntax with `{ }` for hotkey/hotstring handlers

### Elevated Scripts Launch Elevated Children — Use `ShellRun` for GUI Apps

**Symptom:** GUI apps launched with `Run()` (Krita, BeeRef, Sublime, etc.) are elevated
and can't receive drag-and-drop from Explorer (and get blocked by UIPI for other
interactions). Dragging a file into the window does nothing / shows a `∅` cursor.

**Cause:** This script relaunches itself with admin (`Run('*RunAs "' A_ScriptFullPath '"')`
at the top), so every child spawned via `Run()` inherits the elevated token.

**Fix:** Launch interactive GUI apps through `ShellRun()` (the Lexikos ShellRun method) —
it executes via the non-elevated desktop shell COM object, so the child runs at normal
integrity. Arguments go in the second parameter (NOT embedded in the path string):

```ahk
# WRONG — child is elevated, no drag-and-drop:
Run('"C:\Program Files\Krita (x64)\bin\krita.exe"')
Run('"C:\Users\Leonardo\001\00__DEV\BeeRef\.venv\Scripts\beeref.exe" --paste')

# CORRECT — de-elevated via the desktop shell:
ShellRun('C:\Program Files\Krita (x64)\bin\krita.exe')
ShellRun('C:\Users\Leonardo\001\00__DEV\BeeRef\.venv\Scripts\beeref.exe', '--paste')
```

Notes:
- Pass the path WITHOUT surrounding quotes — it is a single `filePath` parameter, not a
  command line; ShellExecute handles spaces itself. Only quote args that need quoting.
- `wt.exe` (Windows Terminal) MUST be launched via `ShellRun` too — an elevated `wt.exe`
  cannot attach to existing non-elevated terminal windows as a new tab.
- `WinWait`/`WinActivate` on the child still works after `ShellRun` (e.g. BeeRef's GUI is
  the child `pythonw.exe`, launched from the now non-elevated `beeref.exe` launcher).

### Detecting a Locked Workstation (Win+L) — Use WM_WTSSESSION_CHANGE, NOT WTSConnectState

**Symptom:** Script keeps firing while the PC is locked; `query session` shows the console
session flip `Active → Disc` on lock, but polling `WTSConnectState` via
`WTSQuerySessionInformation` still reports `WTSActive`.

**Cause:** `WTSConnectState` does NOT reliably flip on Win+L (known community issue).
Even though the docs claim `WTSDisconnected` occurs on lock, in practice it often stays
`WTSActive`. Do NOT poll it for lock state.

**Fix:** Event-driven `WM_WTSSESSION_CHANGE` (0x02B1) via `WTSRegisterSessionNotificationEx`
+ `OnMessage`. Windows sends `WTS_SESSION_LOCK` (0x7) / `WTS_SESSION_UNLOCK` (0x8) on
transition. Keep a global flag and check it from the serial/gate code:

```ahk
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

WM_WTSSESSION_CHANGE(wParam, lParam, msg, hwnd) {   ; 4-param signature is REQUIRED
    global SessionLocked
    if (wParam = 0x7)        ; WTS_SESSION_LOCK
        SessionLocked := true
    else if (wParam = 0x8)   ; WTS_SESSION_UNLOCK
        SessionLocked := false
}
```

The `WM_WTSSESSION_CHANGE` callback signature MUST be the full 4-param form
`(wParam, lParam, msg, hwnd)`.

### OnMessage Callbacks in this AutoHotkeyUX Fork — Object + Full Signature Required

**Symptom 1:** `Error: Parameter #2 of OnMessage requires an Object, but received a String.`
when passing a quoted function name: `OnMessage(0x02B1, "WM_WTSSESSION_CHANGE")`.

**Cause:** This fork's `OnMessage` does NOT accept a string function name — it strictly
requires a function object.

**Symptom 2:** `Error: Invalid callback function.` when passing a bare name with a
shortened signature: `WM_WTSSESSION_CHANGE(wParam, lParam)`.

**Cause:** The callback signature is validated. It must use the full 4-param form.

**Fix:**
```ahk
; Bare function name (NOT quoted) — this fork resolves bare names to function objects,
; exactly like SetTimer ReadSerial, 30 does.
OnMessage(0x02B1, WM_WTSSESSION_CHANGE)

; Callback must declare all 4 parameters.
WM_WTSSESSION_CHANGE(wParam, lParam, msg, hwnd) { ... }
```

### DllCall `&outputVar` Params — Pre-initialize the Variables

**Symptom:** `Error: This local variable has not been assigned a value. Specifically: pp`
thrown at the `DllCall` line itself, even though `&pp` looks like an output-only param.

**Cause:** `#Warn VarUnset, Off` does not cover this. DllCall by-ref output variables
must be assigned before the call in this fork.

**Fix:**
```ahk
pp := 0, bytes := 0
if !DllCall("wtsapi32.dll\WTSQuerySessionInformationW"
    , "Ptr", 0, "UInt", 0xFFFFFFFF, "UInt", 8, "Ptr*", &pp, "UInt*", &bytes)
    return false
```

### WTSQuerySessionInformation Info-Class Reference

- `WTSConnectState` is info class **8** (NOT 6). Class **6** is `WTSWinStationName`
  (returns a 16-byte name like "console" — misleading junk when read as a DWORD).
- Only use this API if you genuinely need connection state; for lock detection use the
  `WM_WTSSESSION_CHANGE` approach above.
- `WTS_CURRENT_SERVER_HANDLE` = `0`; `WTS_CURRENT_SESSION` = `0xFFFFFFFF`.

### PowerShell Profile Functions Are NOT Available in Fresh Shells

**Symptom:** `upkey` (a PowerShell function defined in the user profile) fails with
`The term 'upkey' is not recognized...` when invoked from a fresh pwsh session
(e.g. via AHK `Run()` or a non-interactive shell).

**Cause:** Aliases/functions live in the user's `$PROFILE`, which is only loaded in
interactive sessions, and `Run()` spawns a fresh process without it.

**Fix:** Load the profile explicitly before calling:
```ahk
Run('pwsh.exe -NoLogo -Command ". $PROFILE; upkey"')
```

**Note:** `upkey` = kill all `AutoHotkey*` processes, then restart `STD_HotKeys.ahk`.
Use this to reload the script — do NOT roll your own reload mechanism or spawn an
ad-hoc AHK script (it gets killed by `upkey` anyway).

