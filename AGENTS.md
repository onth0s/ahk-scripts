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

### AHK Version

This project requires **AutoHotkey v2.0** (`#Requires AutoHotkey v2.0`).
Always write AHK v2 syntax:
- Functions use `&` for by-reference output params (e.g., `WinGetPos(&x, &y, &w, &h)`)
- `EnvGet` is an exception — it returns the value directly, no `&`
- `try/catch as err` syntax (not `catch e`)
- Block syntax with `{ }` for hotkey/hotstring handlers
