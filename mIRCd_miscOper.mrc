; mIRCd_miscOper.mrc
;
; This script contains the following command(s): DIE, GET, REHASH, RESTART

alias mIRCd_command_die {
  ; /mIRCd_command_die <sockname> DIE [<password>]

  if ($is_oper($1) == $false) {
    mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
    return
  }
  if ($mIRCd(DIE_PASSWORD) != $null) {
    if ($3 == $null) {
      mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
      return
    }
    if ($mIRCd.encryptPass($3) !== $mIRCd(DIE_PASSWORD)) {
      mIRCd.sraw $1 $mIRCd.reply(464,$mIRCd.info($1,nick))
      return
    }
  }
  ; ,-> No password is required.
  hadd -m $mIRCd.temp DIE $mIRCd.info($1,nick)
  .mIRCd.die
}
alias mIRCd_command_get {
  ; /mIRCd_command_get <sockname> GET [item]

  if ($is_oper($1) == $false) {
    mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
    return
  }
  var %this.loop = 0, %this.search = $iif($3 != $null,$v1,*)
  while (%this.loop < $hfind($mIRCd.main,%this.search,0,w).item) {
    inc %this.loop 1
    var %this.item = $hfind($mIRCd.main,%this.search,%this.loop,w).item
    mIRCd.sraw $1 NOTICE $mIRCd.info($1,nick) $+(:,$upper($2),:) $+(%this.item,=,$hget($mIRCd.main,%this.item)))
  }
}
alias mIRCd_command_rehash {
  ; /mIRCd_command_rehash <sockname> REHASH [section]

  if ($is_oper($1) == $false) {
    mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
    return
  }
  if ($mIRCd.check > 0) {
    mIRCd.sraw NOTICE $mIRCd.info($1,nick) :*** Notice -- Error(s) detected in the config.
    return
  }
  hadd -m $mIRCd.temp REHASH $1
  ; `-> Store the sockname, not the nick. (There's a numeric reply we need to do.)
  .mIRCd.rehash $iif($3 != $null,$v1)
}
alias mIRCd_command_restart {
  ; /mIRCd_command_restart <sockname> RESTART [<password>]

  if ($is_oper($1) == $false) {
    mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
    return
  }
  if ($mIRCd(RESTART_PASSWORD) != $null) {
    if ($3 == $null) {
      mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
      return
    }
    if ($mIRCd.encryptPass($3) !== $mIRCd(RESTART_PASSWORD)) {
      mIRCd.sraw $1 $mIRCd.reply(464,$mIRCd.info($1,nick))
      return
    }
  }
  ; ,-> No password is required.
  hadd -m $mIRCd.temp RESTART $mIRCd.info($1,nick)
  .mIRCd.restart
}

; Commands and Functions

alias divMask {
  ; $divMask(<N>)

  if ($1 > 0) {
    var %this.mask = $1, %this.base = 0, %this.flags = 65536,32768,16384,8192,4096,2048,1024,512,256,128,64,32,16,8,4,2,1,0, %this.output = $null
    while (%this.base < $numtok(%this.flags,44)) {
      inc %this.base 1
      if ($calc(%this.mask % $gettok(%this.flags,%this.base,44)) != %this.mask) { var %this.mask = $v1, %this.output = %this.output $gettok(%this.flags,%this.base,44) }
    }
  }
  return $iif(%this.output != $null,$v1,0)
}
alias mIRCd.serverNotice {
  ; /mIRCd.serverNotice <snomask> <message>

  if ($2 == $null) { return }
  var %this.loop = 0
  while (%this.loop < $hcount($mIRCd.users)) {
    inc %this.loop 1
    var %this.sock = $hget($mIRCd.users,%this.loop).item
    if ($is_modeSet(%this.sock,s).nick == $false) { continue }
    if ($istok($divMask($mIRCd.info(%this.sock,snoMask)),$1,32) == $true) { mIRCd.sraw %this.sock NOTICE $mIRCd.info(%this.sock,nick) :*** Notice -- $2- }
  }
}

; EOF
