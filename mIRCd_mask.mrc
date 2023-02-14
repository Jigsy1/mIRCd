; mIRCd_mask.mrc
;
; This script contains the following command(s): ACCEPT, GLINE, SHUN, SILENCE, ZLINE

on *:signal:mIRCd_timeCheck:{
  if (($hcount($mIRCd.glines) == 0) && ($hcount($mIRCd.shuns) == 0) && ($hcount($mIRCd.zlines) == 0)) { return }
  var %this.time = $+($ctime,:)
  if ($hfind($mIRCd.glines,%this.time,0,r).data > 0) { mIRCd.removePunishment $mIRCd.glines %this.time }
  if ($hfind($mIRCd.shuns,%this.time,0,r).data > 0) { mIRCd.removePunishment $mIRCd.shuns %this.time }
  if ($hfind($mIRCd.zlines,%this.time,0,r).data > 0) { mIRCd.removePunishment $mIRCd.zlines %this.time }
}

; Hash Tables

alias mIRCd.glines { return mIRCd[Glines] }
alias mIRCd.klines { return mIRCd[Klines] }
alias mIRCd.local { return $+(mIRCd[local],$bracket($1)) }
; `-> For local Shuns and Zlines. Like K-lines, these will not expire.
alias mIRCd.shuns { return mIRCd[Shuns] }
alias mIRCd.zlines { return mIRCd[Zlines] }

; IRCd Commands

alias mIRCd_command_accept {
  ; /mIRCd_command_accept <sockname> ACCEPT [<nick>|<-|+n!u@h>]

  if (($pos(-+,$left($3,1)) == $null) || ($3 == $null)) {
    ; ¦-> Show any accepts (for a user).
    ; `-> Please see the note under /mIRCd_command_silence.
    var %this.sock = $1
    if ($getSockname($3) != $null) { var %this.sock = $v1 }
    if ($hcount($mIRCd.accept(%this.sock)) == 0) {
      mIRCd.sraw $1 $mIRCd.reply(162,$mIRCd.info($1,nick),$mIRCd.info(%this.sock,nick))
      return
    }
    var %this.loop = 0
    while (%this.loop < $hcount($mIRCd.accept(%this.sock))) {
      inc %this.loop 1
      var %this.mask = $hget($mIRCd.accept(%this.sock),%this.loop).item
      mIRCd.sraw $1 $mIRCd.reply(161,$mIRCd.info($1,nick),$mIRCd.info(%this.sock,nick),%this.mask)
    }
    mIRCd.sraw $1 $mIRCd.reply(162,$mIRCd.info($1,nick),$mIRCd.info(%this.sock,nick))
    return
  }
  var %this.flag = $left($3,1), %this.mask = $makeMask($right($3,-1))
  if (%this.flag == -) {
    if ($hfind($mIRCd.accept($1),%this.mask,0,w) == 0) { return }
    var %this.loop = $hfind($mIRCd.accept($1),%this.mask,0,w)
    while (%this.loop > 0) {
      mIRCd.delAccept $1 $hfind($mIRCd.accept($1),%this.mask,%this.loop,w).item
      dec %this.loop 1
    }
    mIRCd.raw $1 $+(:,$mIRCd.fulladdr($1)) ACCEPT $3
    return
  }
  ; ,-> Treat everything else as an addition.
  if ($hcount($mIRCd.accept($1)) >= $mIRCd(MAXACCEPT)) {
    if ((%this.flag == +) && ($is_accepted($1,%this.mask) == $false)) {
      mIRCd.sraw $1 $mIRCd.reply(510,$mIRCd.reply($1,nick),%this.mask)
      return
    }
    ; `-> Unless setting the accept will clear up the list in some way.
  }
  var %this.acceptNumber = $hfind($mIRCd.accept($1),%this.mask,0,w)
  while (%this.acceptNumber > 0) {
    mIRCd.delAccept $1 $hfind($mIRCd.accept($1),%this.mask,%this.acceptNumber,w).item
    dec %this.acceptNumber 1
  }
  mIRCd.addAccept $1 %this.mask
  mIRCd.raw $1 $+(:,$mIRCd.fulladdr($1)) ACCEPT $3
}
alias mIRCd_command_gline {
  ; /mIRCd_command_gline <sockname> GLINE [<-|+!RrealName|#chan|user@host> <duration> :<reason>]

  if ($is_oper($1) == $false) {
    mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
    return
  }
  var %this.flag = $left($3,1)
  if (($pos(-+,%this.flag) == $null) || ($3 == $null)) {
    ; `-> Show G-lines.
    var %this.loop = 0
    while (%this.loop < $hcount($mIRCd.glines)) {
      inc %this.loop 1
      var %this.item = $hget($mIRCd.glines,%this.loop).item
      var %this.data = $hget($mIRCd.glines,%this.item)
      mIRCd.sraw $1 $mIRCd.reply(247,$mIRCd.info($1,nick),%this.item,$left($gettok(%this.data,1,32),-1),$gettok(%this.data,2-,32))
    }
    mIRCd.sraw $1 $mIRCd.reply(281,$mIRCd.info($1,nick))
    return
  }
  if (($5- == :) || ($5- == $null)) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  if ($4 !isnum 1-) {
    mIRCd.sraw $1 $mIRCd.reply(515,$mIRCd.info($1,nick),$4)
    return
  }
  var %this.what = $right($3,-1), %this.reason = $5-
  if (%this.flag == -) {
    if ($is_glined(%this.what) == $false) {
      mIRCd.sraw $1 $mIRCd.reply(512,$mIRCd.info($1,nick),%this.what)
      return
    }
    var %this.data = $hget($mIRCd.glines,%this.what)
    mIRCd.serverNotice 512 $mIRCd.info($1,nick) removing local $iif(#* iswm %this.what,BADCHAN,GLINE) for $+(%this.what,$comma) expiring at $gettok(%this.data,1,32) $gettok(%this.data,2-,32)
    mIRCd.deletePunishment $mIRCd.glines %this.what
    return
  }
  ; ,-> +
  if ($left(%this.what,1) == $chr(35)) {
    ; `-> Ban a channel.
    var %this.trim = $trimStars(%this.what)
    if ($is_exists(%this.what).chan == $true) {
      ; ¦-> Make sure the channel exists first, because the restriction on wildcards could prevent G-lining a channel like:
      ; `-> #this***************chan
      mIRCd.serverNotice 512 $mIRCd.info($1,nick) adding local BADCHAN for $+(%this.trim,$comma) expiring at $+($calc($ctime + $4),:) %this.reason
      mIRCd.addPunishment $mIRCd.glines %this.trim $+($calc($ctime + $4),:) %this.reason
      ; `-> Add the G-line first to prevent anyone else joining it.
      var %this.id = $getChanID(%this.what)
      var %this.loop = $hcount($mIRCd.chanUsers(%this.id))
      while (%this.loop > 0) {
        var %this.sock = $hget($mIRCd.chanUsers(%this.id),%this.loop).item
        mIRCd.sraw %this.sock KICK $mIRCd.info(%this.id,name) $mIRCd.info(%this.sock,nick) :Bad channel $parenthesis(%this.reason)
        ; `-> We don't need to inform the others, since they'll be joining them.
        mIRCd.chanDelUser %this.id %this.sock
        dec %this.loop 1
      }
      return
    }
    if ($is_glined(%this.trim) == $true) {
      var %this.data = $hget($mIRCd.glines,%this.trim)
      if ($gettok($left(%this.data,-1),1,32) > $calc($ctime + $4)) {
        ; `-> Revised time is less than the previous time; remove the G-line.
        recurse_gline $1 GLINE $+(-,%this.trim) 1 $gettok(%this.data,2-,32)
        return
      }
      mIRCd.serverNotice 512 $mIRCd.info($1,nick) resetting expiration time on BADCHAN for $+(%this.trim,$comma) expiring at $+($calc($ctime + $4),:) $gettok(%this.data,2-,32)
      mIRCd.addPunishment $mIRCd.glines %this.trim $+($calc($ctime + $4),:) $gettok(%this.data,2-,32)
      return
    }
    if ($percentCheck($right(%this.trim,-1)) > 10) {
      ; `-> Mask too wide. (9% or less wildcards allowed.)
      mIRCd.sraw $1 $mIRCd.reply(520,$mIRCd.info($1,nick),%this.trim)
      return
    }
    ; `-> Check for existing wildcard channels again and deal with them.
    if ($hfind($mIRCd.chans,%this.trim,0,w).data > 0) {
      mIRCd.serverNotice 512 $mIRCd.info($1,nick) adding local BADCHAN for $+(%this.trim,$comma) expiring at $+($calc($ctime + $4),:) %this.reason
      mIRCd.addPunishment $mIRCd.glines %this.trim $+($calc($ctime + $4),:) %this.reason
      ; `-> Again, G-line first.
      var %this.loop = $hfind($mIRCd.chans,%this.trim,0,w).data
      while (%this.loop > 0) {
        var %this.id = $hfind($mIRCd.chans,%this.trim,%this.loop,w).data
        var %this.user = $hcount($mIRCd.chanUsers(%this.id))
        while (%this.user > 0) {
          var %this.sock = $hget($mIRCd.chanUsers(%this.id),%this.user).item
          mIRCd.sraw %this.sock KICK $mIRCd.info(%this.id,name) $mIRCd.info(%this.sock,nick) :Bad channel $parenthesis(%this.reason)
          mIRCd.chanDelUser %this.id %this.sock
          dec %this.user 1
        }
        dec %this.loop 1
      }
      return
    }
    mIRCd.serverNotice 512 $mIRCd.info($1,nick) adding local BADCHAN for $+(%this.trim,$comma) expiring at $+($calc($ctime + $4),:) %this.reason
    mIRCd.addPunishment $mIRCd.glines %this.trim $+($calc($ctime + $4),:) %this.reason
    return
  }
  if ($left(%this.what,2) == !R) {
    ; `-> G-line a user with a matching realName.
    var %this.name = $trimStars($right(%this.what,-2))
    if ($percentCheck(%this.name) > 25) {
      ; `-> Mask too wide. (I'm only allowing <25% of wildcards in the realName.)
      mIRCd.sraw $1 $mIRCd.reply(520,$mIRCd.info($1,nick),%this.name)
      return
    }
    if ($is_glined(%this.name) == $true) {
      var %this.data = $hget($mIRCd.glines,%this.name)
      if ($gettok($left(%this.data,-1),1,32) > $calc($ctime + $4)) {
        ; `-> Revised time is less than the previous time; remove the G-line.
        recurse_gline $1 GLINE $+(-!R,%this.name) 1 $gettok(%this.data,2-,32)
        return
      }
      mIRCd.serverNotice 512 $mIRCd.info($1,nick) resetting expiration time on GLINE for $+(!R,%this.name,$comma) expiring at $+($calc($ctime + $4),:) $gettok(%this.data,2-,32)
      mIRCd.addPunishment $mIRCd.glines $+(!R,%this.name) $+($calc($ctime + $4),:) %this.reason
      return
    }
    mIRCd.serverNotice 512 $mIRCd.info($1,nick) adding local GLINE for $+(!R,%this.name,$comma) expiring at $+($calc($ctime + $4),:) %this.reason
    mIRCd.addPunishment $mIRCd.glines $+(!R,%this.name) $+($calc($ctime + $4),:) %this.reason
    var %this.loop = $hcount($mIRCd.users)
    while (%this.loop > 0) {
      var %this.sock = $hget($mIRCd.users,%this.loop).item, %this.realName = $+(!R,$strip($mIRCd.info(%this.sock,realName)))
      if ($is_glineMatch(%this.realName) == $true) {
        mIRCd.serverNotice 512 G-line active for $mIRCd.info(%this.sock,nick) $parenthesis($gettok($mIRCd.fulladdr(%this.sock),2,33))
        mIRCd.sraw %this.sock $mIRCd.reply(465,$mIRCd.info($1,nick),%this.reason)
        mIRCd.errorUser %this.sock G-lined $parenthesis(%this.reason)
      }
      dec %this.loop 1
    }
    return
  }
  ; ,-> user@host.
  var %this.mask = $gettok($makeMask(%this.what),2,33)
  if ($percentCheck($gettok(%this.mask,2,64)) > 0) {
    ; `-> Mask too wide. (No wildcards allowed in host.)
    mIRCd.sraw $1 $mIRCd.reply(520,$mIRCd.info($1,nick),%this.mask)
    return
  }
  if ($is_glined(%this.mask) == $true) {
    var %this.data = $hget($mIRCd.glines,%this.mask)
    if ($gettok($left(%this.data,-1),1,32) > $calc($ctime + $4)) {
      ; `-> Revised time is less than the previous time; remove the G-line.
      recurse_gline $1 GLINE $+(-,%this.mask) 1 $gettok(%this.data,2-,32)
      return
    }
    mIRCd.serverNotice 512 $mIRCd.info($1,nick) resetting expiration time on GLINE for $+(%this.mask,$comma) expiring at $+($calc($ctime + $4),:) $gettok(%this.data,2-,32)
    mIRCd.addPunishment $mIRCd.glines %this.mask $+($calc($ctime + $4),:) $gettok(%this.data,2-,32)
    return
  }
  mIRCd.serverNotice 512 $mIRCd.info($1,nick) adding local GLINE for $+(%this.mask,$comma) expiring at $+($calc($ctime + $4),:) %this.reason
  mIRCd.addPunishment $mIRCd.glines %this.mask $+($calc($ctime + $4),:) %this.reason
  var %this.loop = $hcount($mIRCd.users)
  while (%this.loop > 0) {
    var %this.sock = $hget($mIRCd.users,%this.loop).item
    if (($is_glineMatch($mIRCd.fulladdr(%this.sock)) == $true) || ($is_glineMatch($mIRCd.ipaddr(%this.sock)) == $true) || ($is_glineMatch($mIRCd.trueaddr(%this.sock)) == $true)) {
      mIRCd.serverNotice 512 G-line active for $mIRCd.info(%this.sock,nick) $parenthesis($gettok($mIRCd.fulladdr(%this.sock),2,33))
      mIRCd.sraw %this.sock $mIRCd.reply(465,$mIRCd.info($1,nick),%this.reason)
      mIRCd.errorUser %this.sock G-lined $parenthesis(%this.reason)
    }
    dec %this.loop 1
  }
}
alias mIRCd_command_shun {
  ; /mIRCd_command_shun <sockname> SHUN [<-|+!realName|user@host> <duration> :<reason>]

  if ($is_oper($1) == $false) {
    mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
    return
  }
  var %this.flag = $left($3,1)
  if (($pos(-+,%this.flag) == $null) || ($3 == $null)) {
    ; `-> List all shuns.
    var %this.loop = 0
    while (%this.loop < $hcount($mIRCd.shuns)) {
      inc %this.loop 1
      var %this.item = $hget($mIRCd.shuns,%this.loop).item
      var %this.data = $hget($mIRCd.shuns,%this.item)
      mIRCd.sraw $1 $mIRCd.reply(290,$mIRCd.info($1,nick),%this.item,$left($gettok(%this.data,1,32),-1),$gettok(%this.data,2-,32))
    }
    if ($hcount($mIRCd.local(Shuns)) > 0) {
      var %this.loop = 0
      while (%this.loop < $hcount($mIRCd.local(Shuns))) {
        inc %this.loop 1
        var %this.item = $hget($mIRCd.local(Shuns),%this.loop).item
        var %this.data = $hget($mIRCd.local(Shuns),%this.item)
        mIRCd.sraw $1 $mIRCd.reply(290,$mIRCd.info($1,nick),%this.item,N/A,%this.data)
      }
    }
    mIRCd.sraw $1 $mIRCd.reply(291,$mIRCd.info($1,nick))
    return
  }
  if (($5- == :) || ($5- == $null)) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  if ($4 !isnum 1-) {
    mIRCd.sraw $1 $mIRCd.reply(515,$mIRCd.info($1,nick),$4)
    return
  }
  var %this.what = $right($3,-1), %this.reason = $5-
  if (%this.flag == -) {
    if ($is_shunned(%this.what) == $false) {
      mIRCd.sraw $1 $mIRCd.reply(594,$mIRCd.info($1,nick),$2)
      return
    }
    var %this.data = $hget($mIRCd.shuns,%this.what)
    mIRCd.serverNotice 512 $mIRCd.info($1,nick) removing local SHUN for $+(%this.what,$comma) expiring at $gettok(%this.data,1,32) $gettok(%this.data,2-,32)
    mIRCd.deletePunishment $mIRCd.shuns %this.what
    return
  }
  ; ,-> +
  if ($left(%this.what,2) == !R) {
    ; `-> Shun a user with a matching realName.
    var %this.name = $trimStars($right(%this.what,-2))
    if ($percentCheck(%this.name) > 25) {
      ; `-> Mask too wide. (I'm only allowing <25% of wildcards in the realName.)
      mIRCd.sraw $1 $mIRCd.info(520,$mIRCd.info($1,nick),%this.name)
      return
    }
    if ($is_shunned(%this.name) == $true) {
      var %this.data = $hget($mIRCd.shuns,%this.name)
      if ($gettok($left(%this.data,-1),1,32) > $calc($ctime + 4)) {
        ; `-> Revised time is less than the previous time; remove the shun.
        recurse_shun $1 SHUN (-!R,%this.name) 1 $gettok(%this.data,2-,32)
        return
      }
      mIRCd.serverNotice 512 $mIRCd.info($1,nick) resetting expiration time on SHUN for $+(!R,%this.name,$comma) expiring at $+($calc($ctime + $4),:) $gettok(%this.data,2-,32)
      mIRCd.addPunishment $mIRCd.shuns $+(!R,%this.name) $+($calc($ctime + $4),:) $gettok(%this.data,2-,32)
      return
    }
    mIRCd.serverNotice 512 $mIRCd.info($1,nick) adding local SHUN for $+(!R,%this.name,$comma) expiring at $+($calc($ctime + $4),:) %this.reason
    mIRCd.addPunishment $mIRCd.shuns $+(!R,%this.name) $+($calc($ctime + $4),:) %this.reason
    var %this.loop = 0
    while (%this.loop < $hcount($mIRCd.users)) {
      inc %this.loop 1
      var %this.sock = $hget($mIRCd.users,%this.loop).item, %this.realName = $+(!R,$strip($mIRCd.info(%this.sock,realName)))
      if ($is_shunMatch(%this.realName) == $true) {
        mIRCd.serverNotice 512 Shun active for $mIRCd.info(%this.sock,nick) $parenthesis($gettok($mIRCd.fulladdr(%this.sock),2,33))
      }
    }
    return
  }
  ; ,-> user@host
  var %this.mask = $gettok($makeMask(%this.what),2,33)
  if ($percentCheck($gettok(%this.mask,2,64)) > 0) {
    ; `-> Mask too wide. (No wildcards allowed in host.)
    mIRCd.sraw $1 $mIRCd.reply(520,$mIRCd.info($1,nick),%this.mask)
    return
  }
  if ($is_shunned(%this.mask) == $true) {
    var %this.data = $hget($mIRCd.shuns,%this.mask)
    if ($gettok($left(%this.data,-1),1,32) > $calc($ctime + $4)) {
      ; `-> Revised time is less than the previous time; remove the shun.
      recurse_shun $1 SHUN $+(-,%this.mask) 1 $gettok(%this.data,2-,32)
      return
    }
    mIRCd.serverNotice 512 $mIRCd.info($1,nick) resetting expiration time on SHUN for $+(%this.mask,$comma) expiring at $+($calc($ctime + $4),:) $gettok(%this.data,2-,32)
    mIRCd.addPunishment $mIRCd.shuns %this.mask $+($calc($ctime + $4),:) $gettok(%this.data,2-,32)
    return
  }
  mIRCd.serverNotice 512 $mIRCd.info($1,nick) adding local SHUN for $+(%this.mask,$comma) expiring at $+($calc($ctime + $4),:) %this.reason
  mIRCd.addPunishment $mIRCd.shuns %this.mask $+($calc($ctime + $4),:) %this.reason
  var %this.loop = 0
  while (%this.loop < $hcount($mIRCd.users)) {
    inc %this.loop 1
    var %this.sock = $hget($mIRCd.users,%this.loop).item
    if (($is_shunMatch($mIRCd.fulladdr(%this.sock)) == $true) || ($is_shunMatch($mIRCd.ipaddr(%this.sock)) == $true) || ($is_shunMatch($mIRCd.trueaddr(%this.sock)) == $true)) {
      mIRCd.serverNotice 512 Shun active for $mIRCd.info(%this.sock,nick) $parenthesis($gettok($mIRCd.fulladdr(%this.sock),2,33))
    }
  }
}
alias mIRCd_command_silence {
  ; /mIRCd_command_silence <sockname> SILENCE [<nick>|<-|+n!u@h>]

  if (($pos(-+,$left($3,1)) == $null) || ($3 == $null)) {
    ; ¦-> Show any silences (for a user).
    ; ¦-> NOTE: Being able to see the silence(s) of other users when non-oper is not a bug on some ircu IRCds. (UnderNet did change this, though.)
    ; `-> However, I am torn if a non-user should be able to see them, or if I should make them self/oper only.
    var %this.sock = $1
    if ($getSockname($3) != $null) { var %this.sock = $v1 }
    if ($hcount($mIRCd.silence(%this.sock)) == 0) {
      mIRCd.sraw $1 $mIRCd.reply(272,$mIRCd.info($1,nick),$mIRCd.info(%this.sock,nick))
      return
    }
    var %this.loop = 0
    while (%this.loop < $hcount($mIRCd.silence(%this.sock))) {
      inc %this.loop 1
      var %this.mask = $hget($mIRCd.silence(%this.sock),%this.loop).item
      mIRCd.sraw $1 $mIRCd.reply(271,$mIRCd.info($1,nick),$mIRCd.info(%this.sock,nick),%this.mask)
    }
    mIRCd.sraw $1 $mIRCd.reply(272,$mIRCd.info($1,nick),$mIRCd.info(%this.sock,nick))
    return
  }
  var %this.flag = $left($3,1), %this.mask = $makeMask($right($3,-1))
  if (%this.flag == -) {
    if ($hfind($mIRCd.silence($1),%this.mask,0,w) == 0) { return }
    var %this.loop = $hfind($mIRCd.silence($1),%this.mask,0,w)
    while (%this.loop > 0) {
      mIRCd.delSilence $1 $hfind($mIRCd.silence($1),%this.mask,%this.loop,w).item
      dec %this.loop 1
    }
    mIRCd.raw $1 $+(:,$mIRCd.fulladdr($1)) SILENCE $3
    return
  }
  ; ,-> Treat everything else as an addition.
  if ($hcount($mIRCd.silence($1)) >= $mIRCd(MAXSILENCE)) {
    if ((%this.flag == +) && ($is_silenced($1,%this.mask) == $false)) {
      mIRCd.sraw $1 $mIRCd.reply(511,$mIRCd.info($1,nick),%this.mask)
      return
    }
    ; `-> Unless setting the silence will clear up the list in some way.
  }
  var %this.silenceNumber = $hfind($mIRCd.silence($1),%this.mask,0,w)
  while (%this.silenceNumber > 0) {
    mIRCd.delSilence $1 $hfind($mIRCd.silence($1),%this.mask,%this.silenceNumber,w).item
    dec %this.silenceNumber 1
  }
  mIRCd.addSilence $1 %this.mask
  mIRCd.raw $1 $+(:,$mIRCd.fulladdr($1)) SILENCE $3
}
alias mIRCd_command_zline {
  ; /mIRCd_command_zline <sockname> ZLINE [<-|+ip> <duration> :<reason>]

  if ($is_oper($1) == $false) {
    mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
    return
  }
  var %this.flag = $left($3,1)
  if (($pos(-+,%this.flag) == $null) || ($3 == $null)) {
    ; `-> Show Z-lines.
    var %this.loop = 0
    while (%this.loop < $hcount($mIRCd.zlines)) {
      inc %this.loop 1
      var %this.item = $hget($mIRCd.zlines,%this.loop).item
      var %this.data = $hget($mIRCd.zlines,%this.item)
      mIRCd.sraw $1 $mIRCd.reply(292,$mIRCd.info($1,nick),%this.item,$left($gettok(%this.data,1,32),-1),$gettok(%this.data,2-,32))
    }
    if ($hcount($mIRCd.local(Zlines)) > 0) {
      var %this.loop = 0
      while (%this.loop < $hcount($mIRCd.local(Zlines))) {
        inc %this.loop 1
        var %this.item = $hget($mIRCd.local(Zlines),%this.loop).item
        var %this.data = $hget($mIRCd.local(Zlines),%this.item)
        mIRCd.sraw $1 $mIRCd.reply(292,$mIRCd.info($1,nick),%this.item,N/A,%this.data)
      }
    }
    mIRCd.sraw $1 $mIRCd.reply(293,$mIRCd.info($1,nick))
    return
  }
  if (($5- == :) || ($5- == $null)) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  if ($4 !isnum 1-) {
    mIRCd.sraw $1 $mIRCd.reply(515,$mIRCd.info($1,nick),$4)
    return
  }
  var %this.ip = $right($3,-1)
  if ($longip(%this.ip) == $null) {
    mIRCd.sraw $1 $mIRCd.reply(595,$mIRCd.info($1,nick),%this.ip)
    return
  }
  var %this.reason = $5-
  if (%this.flag == -) {
    if ($is_zlined(%this.ip) == $false) {
      mIRCd.sraw $1 $mIRCd.reply(596,$mIRCd.info($1,nick),%this.ip)
      return
    }
    var %this.data = $hget($mIRCd.zlines,%this.ip)
    mIRCd.serverNotice 512 $mIRCd.info($1,nick) removing local ZLINE for $+(%this.ip,$comma) expiring at $gettok(%this.data,1,32) $gettok(%this.data,2-,32)
    mIRCd.deletePunishment $mIRCd.zlines %this.ip
    return
  }
  ; ,-> +
  if ($is_zlined(%this.ip) == $true) {
    var %this.data = $hget($mIRCd.zlines,%this.ip)
    if ($gettok($left(%this.data,-1),1,32) > $calc($ctime + $4)) {
      ; `-> Revised time is less than the previous time; remove the Z-line.
      recurse_zline $1 ZLINE $+(-,%this.ip) 1 $gettok(%this.data,2-,32)
      return
    }
    mIRCd.serverNotice 512 $mIRCd.info($1,nick) resetting expiration time on ZLINE for (%this.ip,$comma) expiring at $+($calc($ctime + $4),:) $gettok(%this.data,2-,32)
    mIRCd.addPunishment $mIRCd.zlines %this.ip $+($calc($ctime + $4),:) $gettok(%this.data,2-,32)
    return
  }
  mIRCd.serverNotice 512 $mIRCd.info($1,nick) adding local ZLINE for $+(%this.ip,$comma) expiring at $+($calc($ctime + $4),:) %this.reason
  mIRCd.addPunishment $mIRCd.zlines %this.ip $+($calc($ctime + $4),:) %this.reason
  var %this.loop = $hcount($mIRCd.users)
  while (%this.loop > 0) {
    var %this.sock = $hget($mIRCd.users,%this.loop).item
    if ($is_zlineMatch($sock(%this.sock).ip) == $true) {
      mIRCd.serverNotice 512 Z-line active for $mIRCd.info(%this.sock,nick) $parenthesis($gettok($mIRCd.fulladdr(%this.sock),2,33))
      mIRCd.sraw %this.sock $mIRCd.reply(465,$mIRCd.info(%this.sock,nick),%this.reason)
      mIRCd.errorUser %this.sock Z-lined $parenthesis(%this.reason)
    }
    dec %this.loop 1
  }
}

; Commands and Functions

alias gettokn {
  var %c = \x $+ $base($3,10,16,2)
  returnex $remove($gettok($regsubex($1,/(?<=^| %c )(?=$| %c )/gx,$lf),$2,$3),$lf)
}
alias is_accepted {
  ; $is_accepted(<sockname>,<mask>)

  return $iif($hfind($mIRCd.accept($1),$2,0,w).item > 0,$true,$false)
}
alias is_acceptMatch {
  ; $is_acceptMatch(<sockname>,<fulladdr?>)

  return $iif($hfind($mIRCd.accept($1),$2,0,W).item > 0,$true,$false)
}
alias is_banMatch {
  ; $is_banMatch(<chan ID>,<fulladdr?>)

  return $iif($hfind($mIRCd.chanBans($1),$2,0,W).item > 0,$true,$false)
}
; `-> This one is for checking against fulladdresses. nick!user@host <-MATCHES-> nick!*@*, *!*@host, etc.
alias is_banned {
  ; $is_banned(<chan ID>,<mask>)

  return $iif($hfind($mIRCd.chanBans($1),$2,0,w).item > 0,$true,$false)
}
; `-> Does the ban exist?
alias is_glined {
  ; $is_glined(<input>)

  return $iif($hget($mIRCd.glines,$1) != $null,$true,$false)
}
; `-> 1:1.
alias is_glineMatch {
  ; $is_glineMatch(<input>)

  return $iif($hfind($mIRCd.glines,$1,0,W).item > 0,$true,$false)
}
alias is_klineMatch {
  ; $is_klineMatch(<input>)

  return $iif($hfind($mIRCd.klines,$1,0,W).item > 0,$true,$false)
}
alias is_shunned {
  ; $is_shunned(<input>)[.local]

  return $iif($hget($iif($prop == local,$mIRCd.local(Shuns),$mIRCd.shuns),$1) != $null,$true,$false)
}
alias is_shunMatch {
  ; $is_shunMatch(<input>)[.local]

  return $iif($hfind($iif($prop == local,$mIRCd.local(Shuns),$mIRCd.shuns),$1,0,W).item > 0,$true,$false)
}
; `-> 1:1.
alias is_silenced {
  ; $is_silenced(<sockname>,<mask>)

  return $iif($hfind($mIRCd.silence($1),$2,0,w).item > 0,$true,$false)
}
alias is_silenceMatch {
  ; $is_silenceMatch(<sockname>,<fulladdr?>)

  return $iif($hfind($mIRCd.silence($1),$2,0,W).item > 0,$true,$false)
}
alias is_zlined {
  ; $is_zlined(<ip>)[.local]

  return $iif($hget($iif($prop == local,$mIRCd.local(Zlines),$mIRCd.zlines),$1) != $null,$true,$false)
}
alias is_zlineMatch {
  ; $is_zlineMatch(<ip>)[.local]

  return $iif($hfind($iif($prop == local,$mIRCd.local(Zlines),$mIRCd.zlines),$1,0,W).item > 0,$true,$false)
}
alias makeMask {
  ; $makeMask(<input>)

  if ($1 == $null) { return }
  if ($count($1,!) == 0) {
    if ($count($1,@) == 0) { return $trimStars($+($1,!*@*)) }
    return $trimStars($+(*!,$iif($gettokn($1,1,64) != $null,$v1,*),@,$iif($gettokn($1,2,64) != $null,$v1,*)))
  }
  if ($count($1,@) == 0) { return $trimStars($+($iif($gettokn($1,1,33) != $null,$v1,*),!,$iif($gettokn($1,2,33) != $null,$v1,*),@*)) }
  if ($calc($pos($1,@) - $pos($1,!)) == 1) { return $trimStars($+($iif($gettokn($1,1,33) != $null,$v1,*),!*@,$iif($gettokn($1,2,64) != $null,$v1,*))) }
  if ($gettok($1,2,64) == $null) {
    if ($pos($1,@,1) < $pos($1,!,1)) { return $trimStars($+($iif($gettokn($1,1,33) != $null,$v1,*),!*@*)) }
    return $trimStars($+($iif($gettokn($1,1,33) != $null,$v1,*),!,$iif($gettokn($gettokn($1,1,64),2,33) != $null,$v1,$iif($gettokn($1,2,64) != $null,$v1,*)),@*))
  }
  if ($pos($1,@,1) < $pos($1,!,1)) { return $trimStars($+($iif($gettok($1,1,33) != $null,$v1,*),!*@*)) }
  return $trimStars($+($iif($gettokn($1,1,33) != $null,$v1,*),!,$gettokn($1,2,33)))
}
; `-> v0.5. (It works, but I'm not entirely happy with this.)
alias mIRCd.addAccept {
  ; /mIRCd.addAccept <sockname> <mask>

  hadd -m $mIRCd.accept($1) $2 $ctime
}
alias mIRCd.addSilence {
  ; /mIRCd.addSilence <sockname> <mask>

  hadd -m $mIRCd.silence($1) $2 $ctime
}
alias mIRCd.addPunishment {
  ; /mIRCd.addPunishment <table> <#chan|ip|user@host> <expire time> <reason>

  hadd -m $1 $2 $3 $4-
}
alias mIRCd.delAccept {
  ; /mIRCd.delAccept <sockname> <mask>

  hdel $mIRCd.accept($1) $2
  if ($hcount($mIRCd.accept($1)) == 0) { hfree $mIRCd.accept($1) }
  ; `-> Free the empty table.
}
alias mIRCd.deletePunishment {
  ; /mIRCd.deletePunishment <table> <item>

  hdel $1 $2
}
alias mIRCd.delSilence {
  ; /mIRCd.delSilence <sockname> <mask>

  hdel $mIRCd.silence($1) $2
  if ($hcount($mIRCd.silence($1)) == 0) { hfree $mIRCd.silence($1) }
  ; `-> Free the empty table.
}
alias mIRCd.removePunishment {
  ; /mIRCd.removePunishment <table> <timestamp>

  var %this.type = $mIRCd.glines GLINE, $mIRCd.shuns SHUN, $mIRCd.zlines ZLINE
  var %this.table = $gettok($matchtok(%this.type,$1,1,44),1,32)
  var %this.loop = $hfind(%this.table,$2,0,r).data
  while (%this.loop > 0) {
    var %this.item = $hfind(%this.table,$2,%this.loop,r).data
    mIRCd.serverNotice 512 $iif(#* iswm %this.item,BADCHAN,$gettok($matchtok(%this.type,$1,1,44),2,32)) for %this.item expired $parenthesis($gettok($hget(%this.table,%this.item),2-,32))
    mIRCd.deletePunishment %this.table %this.item
    dec %this.loop 1
  }
}
alias percentCheck {
  ; $percentCheck(<input>)

  return $int($calc((($count($1,*) + $count($1,?)) / $len($1)) * 100))
}
alias recurse_gline { mIRCd_command_gline $1- }
alias recurse_shun { mIRCd_command_shun $1- }
alias recurse_zline { mIRCd_command_zline $1- }
; `-> These three are required.
alias trimStars {
  ; $trimStars(<input>)

  var %this.string = $1, %this.string = $mid($1,$gettok($regsubex(%this.string,/(.)/g,$iif(\t != :,$+(\n,:))),1,58))
  ; `-> $1 must be set as a variable. Also, trim any :'s at the start again.
  return $regsubex($str(.,$len(%this.string)),/./g,$iif($mid(%this.string,\n,1) == *,$iif($mid(%this.string,$calc(\n + 1),1) != *,$mid(%this.string,\n,1)),$mid(%this.string,\n,1)))
}

; EOF
