
; ═══ KEY REMAPS ═══════════════════════════════════════════════════════════════

; CapsLock → Left Shift (global passthrough)
*CapsLock:: {
    Send "{Blind}{LShift DownR}"
}

*CapsLock up:: {
    Send "{Blind}{LShift Up}"
}

; While CapsLock is physically held: Esc toggles the actual CapsLock state/light
#HotIf GetKeyState("CapsLock", "P")
*Esc:: {
    SetCapsLockState(!GetKeyState("CapsLock", "T"))
}
#HotIf  ; ── end context ──

$!F2::Send("3")

; Shift+F10 sends )
$+F10::Send(")")

$!F10::Send("9")

; Alt+4 sends # (hash)
!4::SendText("#")
