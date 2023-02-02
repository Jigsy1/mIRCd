; P10 conversion.
;
; Thanks to Dave (Codex` / Hero_Numer_Zero) for this code.

alias base64toint {
  ; $base64toint(<N>)

  var %o = 0, %x = 1
  while ($mid($1,%x,1) != $null) { 
    var %o = $calc(%o * 64)
    var %o = $calc(%o + $i($v1))
    inc %x
  }
  return %o
}
alias -l i { return $calc($poscs(ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789[],$1)-1) }
alias -l ii { return $mid(ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789[],$calc($int($1) + 1),1) }
alias inttobase64 {
  ; $inttobase64(<N>,<pad to N chars>)

  var %c = $2, %o, %v = $1
  while (%c) {
    var %o = $+($ii($and(%v,63)),%o)
    var %v = $calc(%v / 64) 
    dec %c
  }
  return %o
}

; EOF
