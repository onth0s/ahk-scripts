
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

; F2 sends 3
$F2::Send("3")

; Alt+F2 sends the real F2
$!F2::Send("{F2}")

; F10 sends 9
$F10::Send("9")

; Shift+F10 sends )
$+F10::Send(")")

; Alt+F10 sends the real F10
$!F10::Send("{F10}")

; Ctrl+Numpad3 sends e
$^Numpad3::Send("e")

; Ctrl+Numpad1 sends 4
$^Numpad1::Send("4")

; Alt+4 sends # (hash)
!4::SendText("#")
