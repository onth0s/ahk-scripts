
; ═══ NUMPAD GRID (AutoHotInterception) ═════════════════════════════════════════
; The DEFAULT (built-in) keyboard's numpad becomes a ButtonGrid macro pad, but
; only while the SECONDARY keyboard (VID 0x248A / PID 0x8367) is connected.
; When the secondary is unplugged, the numpad reverts to normal typing.
;
; The 12 mapped keys are blocked at the driver level (Interception) so nothing
; leaks into the focused app — exactly like the hardware ButtonGrid, which sends
; commands rather than keystrokes.
;
; Mapping (numpad key -> grid K):
;   +  -> K1       7 -> K4   4 -> K7   1 -> K10 (layer toggle)
;   -  -> K2       8 -> K5   5 -> K8   2 -> K11
;   BloqNum -> K3  9 -> K6   6 -> K9   3 -> K12
;   / * 0 Enter are NOT mapped and keep normal behavior.

#Include "C:\Users\Leonardo\001\00__DEV\zz - VAR\AutoHotkey\lib\numpad_grid\AutoHotInterception.ahk"

; ── Config ─────────────────────────────────────────────────────────────────────
NUMGRID_SECONDARY_VID := 0x248A
NUMGRID_SECONDARY_PID := 0x8367
; Default keyboard: ACPI embedded keyboard. Resolved by handle (ids can shift
; across reboots). List extra candidate handles if the physical keyboard spans
; more than one HID collection.
NUMGRID_DEFAULT_HANDLES := [
    "ACPI\VEN_MSNB&DEV_1001",
]
NUMGRID_POLL_MS := 2000

; scan code -> K number (10 = layer switch)
NUMGRID_MAP := Map(
    GetKeySC("NumpadAdd"),  1,
    GetKeySC("NumpadSub"),  2,
    GetKeySC("NumLock"),    3,
    GetKeySC("Numpad7"),    4,
    GetKeySC("Numpad8"),    5,
    GetKeySC("Numpad9"),    6,
    GetKeySC("Numpad4"),    7,
    GetKeySC("Numpad5"),    8,
    GetKeySC("Numpad6"),    9,
    GetKeySC("Numpad1"),    10,
    GetKeySC("Numpad2"),    11,
    GetKeySC("Numpad3"),    12,
)

; ── State ──────────────────────────────────────────────────────────────────────
MiniGridLayer     := 0          ; 0 = L1, 1 = L2
MiniGridArmed     := false      ; secondary present AND subscribed
MiniGridSubscribed:= false
MiniGridIds       := []         ; resolved AHI ids for the default keyboard

; ═══════════════════════════════════════════════════════════════════════════════
; ═══ INIT ═════════════════════════════════════════════════════════════════════
; ═══════════════════════════════════════════════════════════════════════════════

try {
    MiniGridAHI := AutoHotInterception()
} catch as err {
    MiniGridAHI := 0
    ToolTip("AutoHotInterception unavailable — numpad grid disabled (" err.Message ")")
    SetTimer(() => ToolTip(), -3000)
}

if MiniGridAHI {
    ; Resolve default keyboard ids from the device list by handle.
    devs := MiniGridAHI.GetDeviceList()
    for id, d in devs {
        if d.IsMouse
            continue
        for h in NUMGRID_DEFAULT_HANDLES {
            if (d.Handle = h)
                MiniGridIds.Push(id)
        }
    }
    if MiniGridIds.Length = 0 {
        ToolTip("Numpad grid: default keyboard handle not found — grid disabled")
        SetTimer(() => ToolTip(), -3000)
        MiniGridAHI := 0
    } else {
        SessionLockCallbacks.Push((*) => MiniGridSyncState())
        SetTimer CheckMiniGridSecondary, NUMGRID_POLL_MS
        MiniGridSyncState()   ; initial sync
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; ═══ WATCHDOG: arm/disable on secondary keyboard connect or session lock/unlock 
; ═══════════════════════════════════════════════════════════════════════════════

CheckMiniGridSecondary() {
    MiniGridSyncState()
}

MiniGridSyncState() {
    global MiniGridAHI, MiniGridArmed, MiniGridSubscribed, SessionLocked
    if !MiniGridAHI
        return
    shouldBeActive := !SessionLocked && MiniGridSecondaryPresent()
    if shouldBeActive && !MiniGridSubscribed {
        if MiniGridSubscribe() {
            MiniGridArmed := true
            MiniGridSubscribed := true
            if !SessionLocked {
                ToolTip("Numpad grid armed (secondary connected)")
                SetTimer(() => ToolTip(), -2000)
            }
        }
    } else if !shouldBeActive && MiniGridSubscribed {
        MiniGridUnsubscribe()
        MiniGridArmed := false
        MiniGridSubscribed := false
        if !SessionLocked {
            ToolTip("Numpad grid disabled (secondary removed)")
            SetTimer(() => ToolTip(), -2000)
        }
    }
}

MiniGridSecondaryPresent() {
    global MiniGridAHI, NUMGRID_SECONDARY_VID, NUMGRID_SECONDARY_PID
    try {
        devs := MiniGridAHI.GetDeviceList()
        for id, d in devs {
            if !d.IsMouse && d.VID = NUMGRID_SECONDARY_VID && d.PID = NUMGRID_SECONDARY_PID
                return true
        }
    }
    return false
}

MiniGridSubscribe() {
    global MiniGridAHI, MiniGridIds, NUMGRID_MAP
    for kbId in MiniGridIds {
        for code, k in NUMGRID_MAP {
            try {
                MiniGridAHI.SubscribeKey(kbId, code, 1, MiniGridDispatch.Bind(k))
            } catch as err {
                ToolTip("Numpad grid subscribe failed (" err.Message ")")
                SetTimer(() => ToolTip(), -3000)
                return false
            }
        }
    }
    return true
}

MiniGridUnsubscribe() {
    global MiniGridAHI, MiniGridIds, NUMGRID_MAP
    for kbId in MiniGridIds {
        for code, k in NUMGRID_MAP {
            try
                MiniGridAHI.UnsubscribeKey(kbId, code)
        }
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; ═══ DISPATCH ═════════════════════════════════════════════════════════════════
; ═══════════════════════════════════════════════════════════════════════════════

; Bound once per subscribed key with its K number captured: MiniGridDispatch(K, state)
MiniGridDispatch(K, state) {
    global MiniGridArmed, MiniGridLayer, SessionLocked
    if state != 1            ; only act on key-down
        return
    if !MiniGridArmed
        return
    if SessionLocked         ; match serial ButtonGrid gating
        return
    if K = 10 {              ; layer switch
        MiniGridLayer := !MiniGridLayer
        ToolTip("Numpad grid layer: L" (MiniGridLayer ? "2" : "1"))
        SetTimer(() => ToolTip(), -1500)
    } else {
        ; Reuse DispatchMacro with a synthesized layer-aware grid command, so the
        ; numpad drives the exact same actions as the hardware ButtonGrid.
        DispatchMacro((MiniGridLayer ? "L2" : "L1") . "_K_" . Format("{:02}", K))
    }
}
