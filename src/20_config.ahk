; ═══ CONFIGURATION ════════════════════════════════════════════════════════════
; Tunable values — edit these to adjust behavior without touching logic.

; Terminal opacity toggle
OPACITY_HIGH := 90
OPACITY_LOW  := 65

; Terminal settings.json path (Windows Terminal)
TERMINAL_SETTINGS_PATH := EnvGet("LOCALAPPDATA") . "\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

; Win+F1: Resize Windows Terminal
TERMINAL_WIDTH_PCT  := 0.74
TERMINAL_HEIGHT_PCT := 0.85
TERMINAL_OFFSET_X   := 25
TERMINAL_OFFSET_Y   := 32

; Win+F1: Snap Task Manager to the right 58% of the monitor it's on
TASKMANAGER_WIDTH_PCT := 0.58
; On a 1920x1080 monitor: snap flush to the top-right at this fraction of height,
; 40% width, nudged 5px toward the right edge
TASKMANAGER_1080P_HEIGHT_PCT := 0.50
TASKMANAGER_1080P_WIDTH_PCT := 0.41
TASKMANAGER_1080P_X_OFFSET := 7

; Win+F1: Resize Microsoft Edge (raw width px, height as % of work area, nudged left)
; *_OFFSET stubs are fine-tune deltas added on top (default 0) for XY position and size.
EDGE_WIDTH_PX       := 1400
EDGE_HEIGHT_PCT     := 1
EDGE_X_OFFSET       := -10
EDGE_POS_X_OFFSET   := 0
EDGE_POS_Y_OFFSET   := -2
EDGE_SIZE_W_OFFSET  := 0
EDGE_SIZE_H_OFFSET  := 10

; Win+F1: Reposition Settings app
SETTINGS_X := 0
SETTINGS_Y := 7
SETTINGS_W := 495
SETTINGS_H := 700

; Win+F1: Reposition Dimmer
DIMMER_X := 7
DIMMER_Y := 709
