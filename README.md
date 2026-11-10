# STD_HotKeys.ahk

Personal AutoHotkey v2 hotkey customizations for Windows — system shortcuts, key
remaps, window management, and two button grids: a hardware grid driven over
serial, plus a numpad grid on the built-in keyboard that arms only while a
secondary keyboard is connected.

## Requirements

- **AutoHotkey v2.0** (v1 is not supported — this is a v2-only codebase)
- A serial device on a configurable COM port (default `COM5`, `9600` baud) if you
  use the serial button grid
- The **Interception driver** + the vendored AutoHotInterception library (in
  `lib/numpad_grid/`) if you use the numpad grid. Install the driver via AHI's
  `InterceptionInstall.gif` once.

## Install & run

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Run `STD_HotKeys.ahk` (double-click, or run it and allow the UAC prompt — the
   script re-launches itself elevated).

The script stays alive in the background (`Persistent`). It re-launches with admin
rights on start, so interactive GUI apps (Krita, BeeRef, Windows Terminal, …) are
launched de-elevated via `ShellRun` to keep normal drag-and-drop / window behavior.

## Reloading

The script auto-kills, rebuilds, and restarts itself via the `upkey` PowerShell
profile function (kill all `AutoHotkey*` processes, merge the `src/*.ahk` splices
via `merge.py` into `STD_HotKeys.ahk`, then restart it):

- In-script: `Ctrl+Alt+Win+ñ`
- From a shell: `. $PROFILE; upkey`

`STD_HotKeys.ahk` is a GENERATED file — do not edit it directly. Source splices
live in `src/` (numbered `00_header.ahk` … `70_debug.ahk`) and are concatenated
in filename order by `python merge.py`. After editing a splice, reload with
`upkey` to rebuild and restart. `Ctrl+Alt+Win+p` opens the `src/` folder.

## System shortcuts

| Hotkey                 | Action                                              |
| ---------------------- | --------------------------------------------------- |
| `Win+E`                | Open Downloads in File Explorer                     |
| `Ctrl+Alt+Win+ñ`       | Reload the script via `upkey`                       |
| `Ctrl+Alt+Win+p`       | Open the `src/` splices folder                      |
| `Ctrl+Win+T`           | Launch Windows Terminal                             |
| `Ctrl+Alt+Win+←/→`     | Previous / next media track                         |
| `Ctrl+Alt+Win+↑/↓`     | Volume up / down by 1 (with notification)           |
| `#^!Shift` (all combos)| Block Office/M365 global intercept                  |
| `Ctrl+Alt+Shift+Win+.` | Show active window info (title, class, proc, pos, size) |

## Window management

`Win+F1` snaps / resizes the active window, depending on which app is focused:

- **Settings app** — fixed position/size
- **Dimmer.exe** — bottom-left corner
- **Windows Terminal** — 74% × 85% of the screen, offset (also used after `LaunchOpencode`)
- **Task Manager** — right 58% of the monitor it's on; on 1920×1080: top-right, 41% width, 50% height
- **Microsoft Edge** — fixed width (1400px), full work-area height, per-monitor DPI aware
- **Fallback** — swallows `Win+F1` elsewhere so Windows Help never opens

`Alt+F1` (Windows Terminal focused) toggles terminal opacity by rewriting
`settings.json` (cycles 90% → 65% → 90%).

## Key remaps

| Remap                        | Effect                      |
| ---------------------------- | --------------------------- |
| `CapsLock`                   | Acts as Left Shift          |
| `Esc` while holding CapsLock | Toggles real CapsLock state |
| `Alt+F2`                     | Sends `3`                   |
| `Shift+F10`                  | Sends `)`                   |
| `Alt+F10`                    | Sends `9`                   |
| `Alt+4`                      | Sends `#`                   |

## Button grid (serial)

A hardware button grid communicates over serial (`CreateFile` on `\\.\COM5`,
`9600` baud, non-blocking reads polled every 30 ms). Commands arrive as lines like
`L1_K_01` and are dispatched in `DispatchMacro`:

- **L1_K_01** — Sublime Text
- **L1_K_03** — Krita, or double-tap to paste into BeeRef (`--paste`)
- **L1_K_04** — Blender (auto-imports `.glb`/`.gltf`/`.obj` if copied in clipboard)
- **L1_K_06** — Telegram Desktop
- **L1_K_11** — Open opencode in Windows Terminal at the clipboard path
  (supports `file:///`, quotes, and `~/` paths)
- **L1_K_12** — Double-tap to open clipboard path history (`Ctrl+Win+x`)
- **L2_K_08 / L2_K_09** — Switch virtual desktops (`Ctrl+Win+Left / Right`)

While the workstation is locked (`WM_WTSSESSION_CHANGE` event), incoming commands
are gated and not dispatched.

## Numpad grid (AutoHotInterception)

The **built-in keyboard's numpad** becomes a second ButtonGrid macro pad, armed
**only while the secondary keyboard (VID `0x248A` / PID `0x8367`) is connected**.
Unplug it and the numpad reverts to normal typing. The mapped keys are blocked at
the driver level (Interception) so nothing leaks into the focused app — exactly
like the hardware grid, which sends commands rather than keystrokes.

Implemented in `src/45_numpad_grid.ahk`; it reuses the exact same `DispatchMacro`
actions as the serial grid (`L1_*` / `L2_*`), so each key behaves identically to
the corresponding hardware button.

Mapping (numpad key → grid K):

| Key | K  | Key | K  |
|-----|----|-----|----|
| `+` | K1 | `6` | K9 |
| `-` | K2 | `1` | **K10 = layer toggle** |
| NumLock (BloqNum) | K3 | `2` | K11 |
| `7` | K4 | `3` | K12 |
| `8` | K5 | `/` `*` `0` `Enter` | not mapped (normal) |
| `9` | K6 |     |     |
| `4` | K7 |     |     |
| `5` | K8 |     |     |

K10 toggles the active layer (L1 ⇄ L2). When Windows locks (`Win+L` / secure
logon), numpad interception is immediately unsubscribed at the driver level so
you can type your Windows password or PIN normally. Upon unlocking, the
ButtonGrid mirror is automatically reinstated if the secondary keyboard is
connected. Keys are also gated by `SessionLocked` like the serial grid; if AHI
or the Interception driver is unavailable the grid degrades gracefully and
stays disabled without terminating the script.

The default keyboard is resolved **by handle** (`ACPI\VEN_MSNB&DEV_1001`) rather
than by numeric id, since Interception ids can shift across reboots. If your
physical numpad's scan codes pass through more than one HID collection, add the
extra handles to `NUMGRID_DEFAULT_HANDLES` in `src/05_config.ahk`.

## Configuration

Tunable values live in `src/05_config.ahk`:

- `ComPort` / `BaudRate` — serial device
- `APP_*` / `DIR_*` — external application and directory paths
- `OPACITY_HIGH` / `OPACITY_LOW` — terminal opacity cycle levels
- `TERMINAL_*`, `TASKMANAGER_*`, `EDGE_*`, `SETTINGS_*`, `DIMMER_*` — window geometry
- `NUMGRID_*` — numpad grid VID/PID, default keyboard handles, and poll interval

## Known gotchas

See `AGENTS.md` in this repo for AutoHotkey v2 pitfalls encountered while building
this script (unset `A_*` built-ins, `ShellRun` de-elevation, session-lock
detection, `OnMessage` callback signature requirements, `""` double-quote parsing, etc.).
