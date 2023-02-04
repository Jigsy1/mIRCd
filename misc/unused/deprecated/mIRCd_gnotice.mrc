; mIRCd_gnotice.mrc
;
; ; This script contains the following command(s): GNOTICE

alias mIRCd_command_gnotice {
  ; /mIRCd_command_gnotice <sockname> GNOTICE <message>

  if ($is_oper($1) == $false) {
    mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
    return
  }
  if (($3- == :) || ($3- == $null)) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.loop = 0
  while (%this.loop < $hcount($mIRCd.users)) {
    inc %this.loop 1
    var %this.sock = $hget($mIRCd.users,%this.loop).item
    mIRCd.raw %this.sock $+(:,$mIRCd.fulladdr($1)) NOTICE $mIRCd.info(%this.sock,nick) $+(:,$bracket(Global Notice),:) $3-
  }
}
; ¦-> This was called GLOBAL, but I had to rename it to GNOTICE because "GLOBAL" is a restricted term in mIRC. (It wouldn't attempt to read GLOBAL.help when doing /HELP.)
; ¦-> Anyway, this existed due to the fact the server didn't support /msg or /notice $* <msg> to all users until I coded it in. (This is deprecated and
; `-> cannot be called, but retained just incase.)

; EOF
