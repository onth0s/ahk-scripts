# STD_HotKeys.ahk

Personal AutoHotkey v2 hotkey customizations for Windows — system shortcuts, key
remaps, window management, and a hardware button grid driven over serial.

## Requirements

- **AutoHotkey v2.0** (v1 is not supported — this is a v2-only codebase)
- A serial device on a configurable COM port (default `COM5`, `9600` baud) if you
  use the button grid

## Install & run

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Run `STD_HotKeys.ahk` (double-click, or run it and allow the UAC prompt — the
   script re-launches itself elevated).

The script stays alive in the background (`Persistent`). It re-launches with admin
rights on start, so interactive GUI apps (Krita, BeeRef, Windows Terminal, …) are
launched de-elevated via `ShellRun` to keep normal drag-and-drop / window behavior.

## Reloading

The script auto-kills and restarts itself via the `upkey` PowerShell profile
function (kill all `AutoHotkey*` processes, then restart `STD_HotKeys.ahk`):

- In-script: `Ctrl+Alt+Win+ñ`
- From a shell: `. $PROFILE; upkey`

## System shortcuts

| Hotkey              | Action                                              |
| ------------------- | --------------------------------------------------- |
| `Win+E`             | Open `C:\Users\Leonardo\Downloads` in File Explorer |
| `Ctrl+Alt+Win+ñ`    | Reload the script via `upkey`                       |
| `Ctrl+Alt+Win+p`    | Open the script in the default editor               |
| `Ctrl+Win+T`        | Launch Windows Terminal                             |
| `Ctrl+Alt+Win+←/→`  | Previous / next media track                         |
| `Ctrl+Alt+Win+↑/↓`  | Volume up / down by 1                               |
| `#^!Shift` (all combos) | Block Office/M365 global intercept             |
| `Ctrl+Alt+Shift+Win+.` | Show active window info (title, class, proc, pos, size) |

## Window management

`Win+F1` snaps / resizes the active window, depending on which app is focused:

- **Settings app** — fixed position/size
- **Dimmer.exe** — bottom-left corner
- **Windows Terminal** — 74% × 85% of the screen, offset (also used after
  `LaunchOpencode`)
- **Task Manager** — right 58% of monitor 1

`Alt+F1` (Windows Terminal focused) toggles terminal opacity by rewriting
`settings.json` (cycles 90% → 65% → 90%).

## Key remaps

| Remap             | Effect                              |
| ----------------- | ----------------------------------- |
| `CapsLock`        | Acts as Left Shift                  |
| `Esc` while holding CapsLock | Toggles real CapsLock state |
| `F2` / `Alt+F2`   | `3` / real `F2`                     |
| `F10` / `Shift+F10` / `Alt+F10` | `9` / `)` / real `F10`  |
| `Ctrl+Numpad3`    | `e`                                 |
| `Ctrl+Numpad1`    | `4`                                 |
| `Alt+4`           | `#`                                 |

## Button grid (serial)

A hardware button grid communicates over serial (`CreateFile` on `\\.\COM5`,
`9600` baud, non-blocking reads polled every 30 ms). Commands arrive as lines like
`L1_K_01` and are dispatched in `DispatchMacro`:

- **L1_K_01** — Sublime Text
- **L1_K_03** — Krita, or double-tap to paste into BeeRef (`--paste`)
- **L1_K_11** — open opencode in Windows Terminal at the clipboard path
  (supports `file:///`, copy-as-path quotes, and `~/` tilde paths)
- **L1_K_12** — double-tap to open clipboard path history (`Ctrl+Win+x`)

While the workstation is locked (`WM_WTSSESSION_CHANGE` event), incoming commands
are gated and not dispatched.

## Configuration

Tunable values live at the top of the `CONFIGURATION` section of the script:

- `ComPort` / `BaudRate` — serial device
- `OPACITY_HIGH` / `OPACITY_LOW` — terminal opacity cycle levels
- `TERMINAL_*`, `TASKMANAGER_*`, `SETTINGS_*`, `DIMMER_*` — window geometry

## Known gotchas

See `AGENTS.md` in this repo for AutoHotkey v2 pitfalls encountered while building
this script (unset `A_*` built-ins, `ShellRun` de-elevation, session-lock
detection, `OnMessage` callback signature requirements, etc.).
