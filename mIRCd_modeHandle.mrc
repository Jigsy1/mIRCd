; mIRCd_modeHandle.mrc
;
; This script contains the following commands: CLEARMODE, MODE, OPER, OPMODE

alias mIRCd_command_clearmode {
  ; /mIRCd_command_clearmode <sockname> CLEARMODE <#chan> [<modestring>]

  if ($is_oper($1) == $false) {
    mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
    return
  }
  if ($3 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  if ($is_exists($3).chan == $false) {
    mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),$3)
    return
  }
  mIRCd.serverNotice 256 HACK(4): $mIRCd.info($1,nick) $upper($2) $3-
  var %this.id = $getChanID($3)
  var %this.clear = $iif($4 != $null,$v1,$+($right($mIRCd.info(%this.id,modes),-1),bohv))
  ; `-> Remember to include bohv if $4 is null, too.
  var %this.minus = -, %this.argMinus = $null, %this.destruct = 0
  var %mIRCd.clearNumber = 0
  while (%mIRCd.clearNumber < $len(%this.clear)) {
    inc %mIRCd.clearNumber 1
    var %this.char = $mid(%this.clear,%mIRCd.clearNumber,1)
    if (%this.char === b) {
      if ($hcount($mIRCd.chanBans(%this.id)) == 0) { continue }
      var %this.banNumber = $hcount($mIRCd.chanBans(%this.id))
      while (%this.banNumber > 0) {
        var %this.banMask = $hget($mIRCd.chanBans(%this.id),%this.banNumber).item
        mIRCd.deleteBan %this.id %this.banMask
        var %this.minus = $+(%this.minus,%this.char)
        var %this.argMinus = %this.argMinus %this.banMask
        dec %this.banNumber 1
        if ($calc($len(%this.minus) - 1) >= $mIRCd(MODESPL)) {
          ; `-> We have to do this now otherwise the line will get too long with bans(s). (We can worry about leftovers later.)
          var %mIRCd.showNumber = 0
          while (%mIRCd.showNumber < $hcount($mIRCd.chanUsers(%this.id))) {
            inc %mIRCd.showNumber 1
            mIRCd.sraw $hget($mIRCd.chanUsers(%this.id),%mIRCd.showNumber).item MODE $3 %this.minus %this.argMinus
          }
          var %this.minus = -, %this.argMinus = $null
        }
      }
      goto cleanupModes
    }
    if ($poscs(hov,%this.char) != $null) {
      if ($hcount($mIRCd.chanUsers(%this.id)) == 0) { continue }
      var %mIRCd.userNumber = 0
      while (%mIRCd.userNumber < $hcount($mIRCd.chanUsers(%this.id))) {
        inc %mIRCd.userNumber 1
        var %this.sock = $hget($mIRCd.chanUsers(%this.id),%mIRCd.userNumber).item
        var %this.data = $gettok($hget($mIRCd.chanUsers(%this.id),%this.sock),3-5,32)
        if ($count(%this.data,1) > 0) {
          var %mIRCd.flagNumber = 0
          while (%mIRCd.flagNumber < $numtok(%this.data,32)) {
            inc %mIRCd.flagNumber 1
            var %this.flag = $gettok(%this.data,%mIRCd.flagNumber,32)
            if (%this.flag == 0) { continue }
            mIRCd.updateChanUser %this.id %this.sock 0 $calc($poscs(ohv,$mid(ohv,%mIRCd.flagNumber,1)) + 2)
            var %this.minus = $+(%this.minus,$mid(ohv,%mIRCd.flagNumber,1))
            var %this.argMinus = %this.argMinus $mIRCd.info(%this.sock,nick)
          }
        }
        if ($calc($len(%this.minus) - 1) >= $mIRCd(MODESPL)) {
          ; `-> Ditto.
          var %mIRCd.showNumber = 0
          while (%mIRCd.showNumber < $hcount($mIRCd.chanUsers(%this.id))) {
            inc %mIRCd.showNumber 1
            mIRCd.sraw $hget($mIRCd.chanUsers(%this.id),%mIRCd.showNumber).item MODE $3 %this.minus %this.argMinus
          }
          var %this.minus = -, %this.argMinus = $null
        }
      }
      goto cleanupModes
    }
    if ($poscs(cgijklmnpstyCNOKPSTY,%this.char) != $null) {
      if ($is_modeSet(%this.id,%this.char).chan == $false) { goto cleanupModes }
      mIRCd.updateChan %this.id modes $removecs($mIRCd.info(%this.id,modes),%this.char)
      var %this.minus = $+(%this.minus,%this.char)
      if (%this.char === k) {
        var %this.argMinus = %this.argMinus $mIRCd.info(%this.id,key)
        mIRCd.delChanItem %this.id key
      }
      if (%this.char === g) { mIRCd.delChanItem %this.id gagTime }
      if (%this.char === j) { mIRCd.delChanItem %this.id joinThrottle }
      if (%this.char === l) { mIRCd.delChanItem %this.id limit }
    }
    :cleanupModes
    ; `-> Deal with the string.
    if ($calc($len(%this.minus) - 1) >= $mIRCd(MODESPL)) {
      ; `-> One more full burst!
      ; mIRCd.modeTell $1 OPMODE %this.id + %this.minus 0 ¦ %this.argMinus
      var %mIRCd.showNumber = 0
      while (%mIRCd.showNumber < $hcount($mIRCd.chanUsers(%this.id))) {
        inc %mIRCd.showNumber 1
        mIRCd.sraw $hget($mIRCd.chanUsers(%this.id),%mIRCd.showNumber).item MODE $3 %this.minus %this.argMinus
      }
      if (P isincs %this.minus) { inc %this.destruct 1 }
      var %this.minus = -, %this.argMinus = $null
    }
  }
  if ($calc($len(%this.minus) - 1) > 0) {
    ; `-> And now the leftovers.
    var %mIRCd.showNumber = 0
    while (%mIRCd.showNumber < $hcount($mIRCd.chanUsers(%this.id))) {
      inc %mIRCd.showNumber 1
      mIRCd.sraw $hget($mIRCd.chanUsers(%this.id),%mIRCd.showNumber).item MODE $3 %this.minus %this.argMinus
    }
    if (P isincs %this.minus) { inc %this.destruct 1 }
  }
  if (%this.destruct == 1) {
    if ($hcount($mIRCd.chanUsers(%this.id)) == 0) { mIRCd.destroyChan %this.id }
  }
}
alias mIRCd_command_mode {
  ; /mIRCd_command_mode <sockname> MODE <target> [<modestring> [args ...]]

  mIRCd.parseMode $1-
}
alias mIRCd_command_oper {
  ; /mIRCd_command_oper <sockname> OPER <account> <password>

  if ($4 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  if ($is_oper($1) == $true) { return }
  var %this.string = Failed $upper($2) attempt by $mIRCd.info($1,nick) $parenthesis($gettok($mIRCd.fulladdr($1),2-,33)) using account: 
  if ($hget($mIRCd.opers,$3) == $null) {
    mIRCd.serverWallops %this.string $3
    mIRCd.sraw $1 $mIRCd.reply(491,$mIRCd.info($1,nick))
    return
  }
  if ($mIRCd.encryptPass($4) !== $hget($mIRCd.opers,$3)) {
    ; `-> !== because of magic hashes.
    mIRCd.serverWallops %this.string $hfind($mIRCd.opers,$hget($mIRCd.opers,$3),1,W).data
    mIRCd.sraw $1 $mIRCd.reply(464,$mIRCd.info($1,nick))
    return
  }
  var %this.modes = $+($iif($is_modeSet($1,g).nick == $false,g),o,$iif($is_modeSet($1,s).nick == $false,s))
  mIRCd.updateUser $1 modes $+($mIRCd.info($1,modes),%this.modes)
  if (s isincs %this.modes) {
    var %this.snoMask = $iif($mIRCd(DEFAULT_OPER_SNOMASK) isnum 1-65535,$v1,17157)
    mIRCd.updateUser $1 snoMask %this.snoMask
    mIRCd.sraw $1 $mIRCd.reply(008,$mIRCd.info($1,nick),%this.snoMask,$base(%this.snoMask,10,16))
    ; `-> This should cover connections, DIE, GLINE, HACK(4), KILL, QUIT and RESTART.
  }
  mIRCd.raw $1 $+(:,$mIRCd.fulladdr($1)) MODE $mIRCd.info($1,nick) $+(:+,%this.modes)
  mIRCd.sraw $1 $mIRCd.reply(381,$mIRCd.info($1,nick))
  hadd -m $mIRCd.opersOnline $1 $ctime
  ; `-> This is a very hacky way of fiddling with the LUSERS numbers.
  mIRCd.serverWallops $mIRCd.info($1,nick) $parenthesis($gettok($mIRCd.fulladdr($1),2-,33)) is now an IRC operator (+o) using account: $hfind($mIRCd.opers,$hget($mIRCd.opers,$3),1,W).data
}
alias mIRCd_command_opmode {
  ; /mIRCd_command_opmode <sockname> OPMODE <#chan> [<modestring> [args ...]]

  if ($is_oper($1) == $false) {
    mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
    return
  }
  if ($3- != $null) { mIRCd.serverNotice 256 HACK(4): $mIRCd.info($1,nick) $upper($2) $3- }
  mIRCd.parseMode $1-
}

; Commands and Functions

alias cleanKey {
  ; $cleanKey(<key>)

  return $strip($gettok($remove($mid($1,$gettok($regsubex($1,/(.)/g,$iif(\t != :,$+(\n,:))),1,58)),$chr(32)),1,44))
}
; `-> Remove any :'s from the front of the key; all spaces, control codes, and only get the first token if split with a comma. E.g. key,key -> key
alias is_chanStatus {
  ; $is_chanStatus(<chan ID>,<sockname>,<mode>)

  return $bool_fmt($gettok($hget($mIRCd.chanUsers($1),$2),$calc($poscs(ohv,$3) + 2),32))
}
alias is_hop {
  ; $is_hop(<chan ID>,<sockname>)

  var %this.id = $1
  return $bool_fmt($gettok($hget($mIRCd.chanUsers(%this.id),$2),4,32))
}
alias is_modeSet {
  ; $is_modeSet(<chan ID|sockname>,<mode>)<.chan|.nick>

  if ($istok(chan nick,$prop,32) != $null) { return $iif($2 isincs $mIRCd.info($1,modes),$true,$false) }
}
alias is_op {
  ; $is_op(<chan ID>,<sockname>)

  var %this.id = $1
  return $bool_fmt($gettok($hget($mIRCd.chanUsers(%this.id),$2),3,32))
}
alias is_open {
  ; $is_open(<chan ID>,<sockname>)

  var %this.id = $1, %this.flags = i k O $iif($hcount($mIRCd.chanUsers($1)) >= $mIRCd.info($1,limit),l) $iif($sock($2).to < $mIRCd.info($1,joinThrottle),j)
  ; `-> We need to account for +l channel(s) being full or not, and for +j being less or greater than the time the user has been connected to the IRCd.
  return $iif($count($regsubex($mIRCd.info(%this.id,modes),/(.)/g,$iif($istokcs(%this.flags,\t,32) == $true,1,0)),1) > 0,$false,$true)
}
alias is_oper {
  ; $is_oper(<sockname>)

  return $iif(o isincs $mIRCd.info($1,modes),$true,$false)
}
alias is_private {
  ; $is_private(<chan ID>)

  var %this.id = $1
  return $iif(p isincs $mIRCd.info(%this.id,modes),$true,$false)
}
alias is_regUser {
  ; $is_regUser(<chan ID>,<sockname>)

  var %this.id = $1
  return $iif($count($gettok($hget($mIRCd.chanUsers(%this.id),$2),3-5,32),1) == 0,$true,$false)
}
alias is_secret {
  ; $is_secret(<chan ID>)

  var %this.id = $1
  return $iif(s isincs $mIRCd.info(%this.id,modes),$true,$false)
}
alias is_voice {
  ; $is_voice(<chan ID>,<sockname>)

  var %this.id = $1
  return $bool_fmt($gettok($hget($mIRCd.chanUsers(%this.id),$2),5,32))
}
alias mIRCd.chanModes { return $+(bcg,$iif($hget($mIRCd.temp,HALFOP) == 1,h),ijklmnopstuvyCHNOK,$iif($hget($mIRCd.temp,PERSISTANT_CHANNELS) == 1,P),STY) $+(bg,$iif($hget($mIRCd.temp,HALFOP) == 1,h),jklov) }
alias mIRCd.chanModesSupport { return b,k,gjl, $+ $+(cimnpstuyCHNOK,$iif($hget($mIRCd.temp,PERSISTANT_CHANNELS) == 1,P),STY) }
; `-> RPL_ISUPPORT. If you remove a mode from chanModes, just remember to _CAREFULLY_ remove it from here, too.
alias -l mIRCd.defaultChanModes { return nt }
; `-> These are the fallback modes for the function right at the bottom of the script. (No need for the + here, we'll deal with that.)
; ,-> Buckle up, kids!
alias -l mIRCd.parseMode {
  ; /mIRCd.parseMode [<args>]

  if ($3 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  if ($is_valid($3).chan == $false) {
    ; `-> User.
    if ($2 == OPMODE) {
      ; `-> OPMODE cannot be used for user mode(s).
      mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
      return
    }
    if ($3 != $mIRCd.info($1,nick)) {
      if ($is_oper($1) == $false) {
        mIRCd.raw $1 $mIRCd.reply(502,$mIRCd.info($1,nick))
        return
      }
      var %this.sock = $getSockname($3)
      if (%this.sock == $null) {
        mIRCd.sraw $1 $mIRCd.reply(401,$mIRCd.info($1,nick),$3)
        return
      }
      if ($4 != $null) {
        mIRCd.sraw $1 $mIRCd.reply(502,$mIRCd.info($1,nick))
        return
      }
      mIRCd.sraw $1 $mIRCd.reply(221,$mIRCd.info(%this.sock,nick),$mIRCd.info(%this.sock,modes))
      return
    }
    if ($4 == $null) {
      mIRCd.sraw $1 $mIRCd.reply(221,$mIRCd.info($1,nick),$mIRCd.info($1,modes))
      return
    }
    var %this.flag = $null, %this.minus = -, %this.plus = +, %this.isSet = $null
    var %this.mode = 0
    while (%this.mode < $len($4)) {
      inc %this.mode 1
      var %this.char = $mid($4,%this.mode,1)
      if (%this.flag != $null) {
        ; `-> - or + have been set.
        var %this.isSet = $is_modeSet($1,%this.char).nick
        if ($pos(-+,%this.char) != $null) {
          var %this.flag = %this.char
          continue
        }
        if (%this.char !isincs $mIRCd.userModes) {
          mIRCd.sraw $1 $mIRCd.reply(501,$mIRCd.info($1,nick),%this.char)
          continue
        }
        if ($poscs(cS,%this.char) != $null) {
          if (%this.flag == -) {
            if (%this.isSet == $false) { continue }
            mIRCd.updateUser $1 modes $removecs($mIRCd.info($1,modes),%this.char)
            var %this.minus = $+(%this.minus,%this.char)
            if (%this.char isincs %this.plus) { var %this.plus = $removecs(%this.plus,%this.char) }
            continue
          }
          ; ,-> +
          if (%this.isSet == $true) { continue }
          mIRCd.updateUser $1 modes $+($mIRCd.info($1,modes),%this.char)
          var %this.plus = $+(%this.plus,%this.char)
          if (%this.char isincs %this.minus) { var %this.minus = $removecs(%this.minus,%this.char) }
          var %this.polar = $iif(%this.char === c,S,c)
          ; `-> Make sure that the polar opposite isn't set. +c cannot be set as well as +S.
          if ($is_modeSet($1,%this.polar).nick == $true) {
            mIRCd.updateUser $1 modes $removecs($mIRCd.info($1,modes),%this.polar)
            var %this.minus = $+(%this.minus,%this.polar)
            if (%this.polar isincs %this.plus) { var %this.plus = $removecs(%this.plus,%this.polar) }
          }
          continue
        }
        if ($poscs(dgiknoswxCDIMWX,%this.char) != $null) {
          if (%this.flag == -) {
            if ((%this.isSet == $false) || (%this.char === x)) { continue }
            ; `-> +x may not be unset.
            mIRCd.updateUser $1 modes $removecs($mIRCd.info($1,modes),%this.char)
            var %this.minus = $+(%this.minus,%this.char)
            if (%this.char isincs %this.plus) { var %this.plus = $removecs(%this.plus,%this.char) }
            if ($poscs(io,%this.char) != $null) { hdel $iif(%this.char === i,$mIRCd.invisible,$mIRCd.opersOnline) $1 }
            ; `-> This is a very hacky way of fiddling with the /LUSERS numbers.
            continue
          }
          ; ,-> +
          if (%this.isSet == $true) {
            if (%this.char === s) {
              if ($is_oper($1) == $false) { continue }
              ; `-> This is the only usermode which has an arg - a number. (See: https://www.undernet.org/docs/snomask-server-notice-masks)
              if ($5 !isnum 1-65536) {
                if (($5 <= 0) || ($5 > 65536)) {
                  ; `-> Remove +s.
                  mIRCd.updateUser $1 modes $removecs($mIRCd.info($1,modes),%this.char)
                  var %this.minus = $+(%this.minus,%this.char)
                  if (%this.char isincs %this.plus) { var %this.plus = $removecs(%this.plus,%this.char) }
                }
                continue
              }
              if ($5 != $mIRCd.info($1,snoMask)) {
                mIRCd.updateUser $1 snoMask $5
                mIRCd.sraw $1 $mIRCd.reply(008,$mIRCd.info($1,nick),$5,$base($5,10,16))
              }
            }
            continue
          }
          if (%this.char === o) { continue }
          ; `-> +o cannot be set except via /OPER.
          if ($poscs(gkWX,%this.char) != $null) {
            if ($is_oper($1) == $false) { continue }
          }
          mIRCd.updateUser $1 modes $+($mIRCd.info($1,modes),%this.char)
          var %this.plus = $+(%this.plus,%this.char)
          if (%this.char isincs %this.minus) { var %this.minus = $removecs(%this.minus,%this.char) }
          if (%this.char === i) { hadd -m $mIRCd.invisible $1 $ctime }
          ; `-> Ditto.
          continue
        }
      }
      else {
        if ($pos(-+,%this.char) != $null) { var %this.flag = %this.char }
      }
    }
    if ($calc($len(%this.minus) + $len(%this.plus)) > 2) {
      if (%this.plus != +) { var %this.string = $v1 }
      if (%this.minus != -) { var %this.string = $+(%this.string,$v1) }
      mIRCd.raw $1 $+(:,$mIRCd.fulladdr($1)) MODE $mIRCd.info($1,nick) $+(:,%this.string)
      if (x isincs %this.plus) {
        ; `-> Obfuscate the host.
        mIRCd.hostQuit $1
      }
      if (s isincs %this.minus) {
        var %this.snoMask = $mIRCd(DEFAULT_SNOMASK)
        mIRCd.updateUser $1 snoMask %this.snoMask
        mIRCd.sraw $1 $mIRCd.reply(008,$mIRCd.info($1,nick),%this.snoMask,$base(%this.snoMask,10,16))
      }
      var %this.wallString = $mIRCd.info($1,nick) $parenthesis($gettok($mIRCd.fulladdr($1),2,33)) has set usermode
      if (k isincs %this.plus) { mIRCd.serverWallops %this.wallString +k (Network Service) }
      if (X isincs %this.plus) { mIRCd.serverWallops %this.wallString +X (Oper Override) }
    }
    ; `-> MODESPL doesn't matter for usermode(s). Also, it's the only mode which is colonized.
    return
  }
  ; ,-> Channel.
  if ($is_exists($3).chan == $false) {
    mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),$3)
    return
  }
  var %this.id = $getChanID($3), %this.name = $mIRCd.info(%this.id,name)
  if ($4 == $null) {
    ; `-> Show modes.
    if ($2 == OPMODE) {
      mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
      return
    }
    if (($is_secret(%this.id) == $true) && ($bool_fmt($mIRCd(DENY_SECRET)) == $true) && ($is_on(%this.id,$1) == $false)) {
      ; `-> If TRUE, deny the existence of secret channels.
      if ($is_oper($1) == $false) {
        mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),$3)
        return
      }
    }
    var %this.modeString = $mIRCd.info(%this.id,modes), %this.modeItem = g gagTime,j joinThrottle,l limit,k key
    var %this.key = $iif($is_oper($1) == $false && $is_on(%this.id,$1) == $false,*,$mIRCd.info(%this.id,key))
    var %this.modeArgs = $regsubex(%this.modeString,/(.)/g,$iif($poscs(gjlk,\t) != $null,$+($iif(\t === k,%this.key,$mIRCd.info(%this.id,$gettok($matchtokcs(%this.modeItem,$+(\t,$chr(32)),1,44),2,32))),$chr(32))))
    mIRCd.sraw $1 $mIRCd.reply(324,$mIRCd.info($1,nick),%this.name,%this.modeString) $iif(%this.modeArgs != $null,$v1)
    mIRCd.sraw $1 $mIRCd.reply(329,$mIRCd.info($1,nick),%this.name,$mIRCd.info(%this.id,createTime))
    return
  }
  if ($istokcs(b -b +b,$4,32) == $true) {
    if ($5 == $null) { goto parseBanlist }
  }
  if ($2 == OPMODE) { goto parseOpmode }
  if ($is_on(%this.id,$1) == $false) {
    if ($is_modeSet($1,X).nick == $false) {
      if (($is_secret(%this.id) == $true) && ($bool_fmt($mIRCd(DENY_SECRET)) == $true)) {
        mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),$3)
        return
      }
      mIRCd.sraw $1 $mIRCd.reply(442,$mIRCd.info($1,nick),%this.name)
      return
    }
  }
  if (($is_op(%this.id,$1) == $false) && ($is_hop(%this.id,$1) == $false) && ($is_modeSet($1,X).nick == $false)) {
    mIRCd.sraw $1 $mIRCd.reply(482,$mIRCd.info($1,nick),%this.name)
    return
  }
  ; ,-> Everything below is quite literally the point of no /return.
  var %this.status = $iif($is_op(%this.id,$1) == $true,1,$iif($is_modeSet($1,X).nick == $true,1,0)) $iif($is_hop(%this.id,$1) == $true,1,0)
  :parseOpmode
  var %this.flag = $null, %this.minus = -, %this.plus = +, %this.isSet = $null, %this.argMinus = $null, %this.argPlus = $null, %this.argv = 0, %this.destruct = 0
  var %this.mode = 0
  while (%this.mode < $len($4)) {
    inc %this.mode 1
    var %this.char = $mid($4,%this.mode,1)
    if (%this.flag != $null) {
      ; `-> - or + has been set.
      var %this.isSet = $is_modeSet(%this.id,%this.char).chan
      if ($pos(-+,%this.char) != $null) {
        var %this.flag = %this.char
        goto cleanupModes
      }
      if (%this.char !isincs $mIRCd.chanModes) {
        mIRCd.sraw $1 $mIRCd.reply(472,$mIRCd.info($1,nick),%this.char)
        goto cleanupModes
      }
      if (%this.char === b) {
        inc %this.argv 1
        var %this.token = $gettok($5-,%this.argv,32)
        if (%this.token == $null) {
          :parseBanlist
          if ($hcount($mIRCd.chanBans(%this.id)) > 0) {
            var %this.banLoop = 0
            while (%this.banLoop < $hcount($mIRCd.chanBans(%this.id))) {
              inc %this.banLoop 1
              var %this.banItem = $hget($mIRCd.chanBans(%this.id),%this.banLoop).item
              mIRCd.sraw $1 $mIRCd.reply(367,$mIRCd.info($1,nick),%this.name,%this.banItem) $hget($mIRCd.chanBans(%this.id),%this.banItem)
            }
          }
          mIRCd.sraw $1 $mIRCd.reply(368,$mIRCd.info($1,nick),%this.name)
          if ($istokcs(b -b +b,$4,32) == $true) { return }
          ; `-> They only wanted to view the banlist.
          goto cleanupModes
        }
        var %this.mask = $makeMask(%this.token)
        if ($hcount($mIRCd.chanBans(%this.id)) >= $mIRCd(MAXBANS)) {
          if ((%this.flag == +) && ($is_banned(%this.id,%this.mask) == $false)) {
            mIRCd.sraw $1 $mIRCd.reply(478,$mIRCd.info($1,nick),%this.name,%this.mask)
            goto cleanupModes
          }
          ; `-> Unless setting the ban will clear the list in some way.
        }
        var %this.banNumber = $hfind($mIRCd.chanBans(%this.id),%this.mask,0,w)
        while (%this.banNumber > 0) {
          var %this.banMask = $hfind($mIRCd.chanBans(%this.id),%this.mask,%this.banNumber,w).item
          var %this.minus = $+(%this.minus,%this.char)
          var %this.minusToken = $+(%this.char,:,%this.banMask)
          var %this.argMinus = %this.argMinus %this.minusToken
          if ($istokcs(%this.argPlus,%this.minusToken,32) == $true) {
            var %this.argPlus = $remtokcs(%this.argPlus,%this.minusToken,1,32)
            var %this.plus = $remove($remtokcs($regsubex(%this.plus,/(.)/g,$+(\t,.)),%this.char,1,46),.)
          }
          mIRCd.deleteBan %this.id %this.banMask
          dec %this.banNumber 1
          ; `-> This might get too long, so we might need to do a MODESPL check now.
        }
        if (%this.flag == +) {
          if ($hget($mIRCd.chanBans(%this.id),%this.mask) != $null) { goto cleanupModes }
          var %this.plus = $+(%this.plus,%this.char)
          var %this.plusToken = $+(%this.char,:,%this.mask)
          var %this.argPlus = %this.argPlus %this.plusToken
          if ($istokcs(%this.argMinus,%this.plusToken,32) == $true) {
            var %this.argMinus = $remtokcs(%this.argMinus,%this.plusToken,1,32)
            var %this.minus = $remove($remtokcs($regsubex(%this.minus,/(.)/g,$+(\t,.)),%this.char,1,46),.)
          }
          mIRCd.addBan %this.id %this.mask $iif($2 == OPMODE,$hget($mIRCd.temp,SERVER_NAME),$mIRCd.fulladdr($1)) $ctime
        }
        goto cleanupModes
      }
      if ($poscs(gjl,%this.char) != $null) {
        var %mode.hashItems = g gagTime,j joinThrottle,l limit, %this.hashItem = $gettok($matchtokcs(%mode.hashItems,$+(%this.char,$chr(32)),1,44),2,32)
        if (%this.flag == -) {
          ; `-> Do not check for tokens in -g/l.
          if (%this.isSet == $false) { goto cleanupModes }
          mIRCd.updateChan %this.id modes $removecs($mIRCd.info(%this.id,modes),%this.char)
          var %this.minus = $+(%this.minus,%this.char)
          if (%this.char isincs %this.plus) {
            var %this.plus = $removecs(%this.plus,%this.char)
            var %this.argPlus = $remtokcs(%this.argPlus,$+(%this.char,:,$mIRCd.info(%this.id,%this.hashItem)),1,32)
          }
          mIRCd.delChanItem %this.id %this.hashItem
          goto cleanupModes
        }
        ; ,-> +
        inc %this.argv 1
        var %this.token = $gettok($5-,%this.argv,32)
        if ((%this.token == $null) || (%this.token !isnum 1-)) {
          mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2,%this.char)
          goto cleanupModes
        }
        if (%this.isSet == $false) {
          mIRCd.updateChan %this.id modes $+($mIRCd.info(%this.id,modes),%this.char)
          var %this.plus = $+(%this.plus,%this.char)
          var %this.plusToken = $+(%this.char,:,%this.token)
          var %this.argPlus = %this.argPlus %this.plusToken
          if (%this.char isincs %this.minus) { var %this.minus = $removecs(%this.minus,%this.char) }
          mIRCd.updateChan %this.id %this.hashItem %this.token
          goto cleanupModes
        }
        ; ,-> Update the number.
        if (%this.token != $mIRCd.info(%this.id,%this.hashItem)) {
          if (%this.char !isincs %this.plus) {
            var %this.plus = $+(%this.plus,%this.char)
            var %this.plusToken = $+(%this.char,:,%this.token)
            var %this.argPlus = %this.argPlus %this.plusToken
          }
          if (%this.char isincs %this.minus) { var %this.minus = $removecs(%this.minus,%this.char) }
          mIRCd.updateChan %this.id %this.hashItem $gettok(%this.plusToken,2,58)
          ; `-> If someone does +lll 8 13 21, it should set 8 as the limit.
        }
        goto cleanupModes
      }
      if (%this.char === k) {
        inc %this.argv 1
        var %this.token = $gettok($5-,%this.argv,32)
        if (%this.token == $null) {
          mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2,%this.char)
          goto cleanupModes
        }
        if (%this.flag == -) {
          if (%this.isSet == $false) {
            mIRCd.sraw $1 $mIRCd.reply(467,$mIRCd.info($1,nick),%this.name)
            goto cleanupModes
          }
          if (%this.token !== $mIRCd.info(%this.id,key)) {
            mIRCd.sraw $1 $mIRCd.reply(467,$mIRCd.info($1,nick),%this.name)
            goto cleanupModes
          }
          var %this.lastKey = $+(%this.char,:,$mIRCd.info(%this.id,key))
          mIRCd.updateChan %this.id modes $removecs($mIRCd.info(%this.id,modes),%this.char)
          var %this.minus = $+(%this.minus,%this.char)
          var %this.minusToken = $+(%this.char,:,%this.token)
          var %this.argMinus = %this.argMinus %this.minusToken
          if (%this.char isincs %this.plus) {
            var %this.plus = $removecs(%this.plus,%this.char)
            var %this.argPlus = $remtokcs(%this.argPlus,%this.minusToken,1,32)
          }
          mIRCd.delChanItem %this.id key
          goto cleanupModes
        }
        ; ,-> +
        var %this.key = $left($cleanKey(%this.token),$mIRCd(KEYLEN))
        if (%this.key == $null) {
          mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2,%this.char)
          goto cleanupModes
        }
        if (%this.isSet == $true) {
          mIRCd.sraw $1 $mIRCd.reply(467,$mIRCd.info($1,nick),%this.name)
          goto cleanupModes
        }
        mIRCd.updateChan %this.id modes $+($mIRCd.info(%this.id,modes),%this.char)
        var %this.plus = $+(%this.plus,%this.char)
        var %this.plusToken = $+(%this.char,:,%this.key)
        var %this.argPlus = %this.argPlus %this.plusToken
        if (%this.char isincs %this.minus) {
          var %this.minus = $removecs(%this.minus,%this.char)
          var %this.argMinus = $remtokcs(%this.argMinus,%this.lastKey,1,32)
        }
        mIRCd.updateChan %this.id key %this.key
        goto cleanupModes
      }
      if ($poscs(hov,%this.char) != $null) {
        inc %this.argv 1
        var %this.token = $gettok($5-,%this.argv,32)
        if (%this.token == $null) { goto cleanupModes }
        var %this.target = $getSockname(%this.token)
        if (%this.target == $null) {
          mIRCd.sraw $1 $mIRCd.reply(401,$mIRCd.info($1,nick),%this.token)
          goto cleanupModes
        }
        if ($is_on(%this.id,%this.target) == $false) {
          mIRCd.sraw $1 $mIRCd.reply(441,$mIRCd.info($1,nick),$mIRCd.info(%this.target,nick))
          goto cleanupModes
        }
        if (($gettok(%this.status,1,32) == 0) && ($poscs(ho,%this.char) != $null)) {
          mIRCd.sraw $1 $mIRCd.reply(482,$mIRCd.info($1,nick),%this.name)
          goto cleanupModes
        }
        if (%this.flag == -) {
          if ($is_chanStatus(%this.id,%this.target,%this.char) == $false) { goto cleanupModes }
          if ((%this.char === o) && ($is_modeSet(%this.target,k).nick == $true)) {
            if ($2 != OPMODE) {
              mIRCd.sraw $1 $mIRCd.reply(484,$mIRCd.info($1,nick),$mIRCd.info(%this.target,nick),%this.name)
              goto cleanupModes
            }
          }
          mIRCd.updateChanUser %this.id %this.target 0 $calc($poscs(ohv,%this.char) + 2)
          var %this.minus = $+(%this.minus,%this.char)
          var %this.minusToken = $+(%this.char,:,%this.token)
          var %this.argMinus = %this.argMinus %this.minusToken
          if ($istokcs(%this.argPlus,%this.minusToken,32) == $true) {
            var %this.argPlus = $remtokcs(%this.argPlus,%this.MinusToken,1,32)
            var %this.plus = $remove($remtokcs($regsubex(%this.plus,/(.)/g,$+(\t,.)),%this.char,1,46),.)
          }
          goto cleanupModes
        }
        ; ,-> +
        if ($is_chanStatus(%this.id,%this.target,%this.char) == $true) { goto cleanupModes }
        mIRCd.updateChanUser %this.id %this.target 1 $calc($poscs(ohv,%this.char) + 2)
        var %this.plus = $+(%this.plus,%this.char)
        var %this.plusToken = $+(%this.char,:,%this.token)
        var %this.argPlus = %this.argPlus %this.plusToken
        if ($istokcs(%this.argMinus,%this.plusToken,32) == $true) {
          var %this.argMinus = $remtokcs(%this.argMinus,%this.plusToken,1,32)
          var %this.minus = $remove($remtok($regsubex(%this.minus,/(.)/g,$+(\t,.)),%this.char,1,46),.)
        }
        goto cleanupModes
      }
      if ($poscs(imntuyCHNKOPTY,%this.char) != $null) {
        if ($poscs(OP,%this.char) != $null) {
          if ($is_oper($1) == $false) {
            mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
            goto cleanupModes
          }
        }
        if (%this.flag == -) {
          if (%this.isSet == $false) { goto cleanupModes }
          mIRCd.updateChan %this.id modes $removecs($mIRCd.info(%this.id,modes),%this.char)
          var %this.minus = $+(%this.minus,%this.char)
          if (%this.char isincs %this.plus) { var %this.plus = $removecs(%this.plus,%this.char) }
          goto cleanupModes
        }
        ; ,-> +
        if (%this.isSet == $true) { goto cleanupModes }
        mIRCd.updateChan %this.id modes $+($mIRCd.info(%this.id,modes),%this.char)
        var %this.plus = $+(%this.plus,%this.char)
        if (%this.char isincs %this.minus) { var %this.minus = $removecs(%this.minus,%this.char) }
        goto cleanupModes
      }
      if ($poscs(cS,%this.char) != $null) {
        if (%this.flag == -) {
          if (%this.isSet == $false) { goto cleanupModes }
          mIRCd.updateChan %this.id modes $removecs($mIRCd.info(%this.id,modes),%this.char)
          var %this.minus = $+(%this.minus,%this.char)
          if (%this.char isincs %this.plus) { var %this.plus = $removecs(%this.plus,%this.char) }
          goto cleanupModes
        }
        ; ,-> +
        if (%this.isSet == $true) { goto cleanupModes }
        mIRCd.updateChan %this.id modes $+($mIRCd.info(%this.id,modes),%this.char)
        var %this.plus = $+(%this.plus,%this.char)
        if (%this.char isincs %this.minus) { var %this.minus = $removecs(%this.minus,%this.char) }
        var %this.polar = $iif(%this.char === c,S,c)
        ; `-> Make sure that the polar opposite isn't set. +c cannot be set as well as +S.
        if ($is_modeSet(%this.id,%this.polar).chan == $true) {
          mIRCd.updateChan %this.id modes $removecs($mIRCd.info(%this.id,modes),%this.polar)
          var %this.minus = $+(%this.minus,%this.polar)
          if (%this.polar isincs %this.plus) { var %this.plus = $removecs(%this.plus,%this.polar) }
        }
        goto cleanupModes
      }
      if ($poscs(ps,%this.char) != $null) {
        if (%this.flag == -) {
          if (%this.isSet == $false) { goto cleanupModes }
          mIRCd.updateChan %this.id modes $removecs($mIRCd.info(%this.id,modes),%this.char)
          var %this.minus = $+(%this.minus,%this.char)
          if (%this.char isincs %this.plus) { var %this.plus = $removecs(%this.plus,%this.char) }
          goto cleanupModes
        }
        ; ,-> +
        if (%this.isSet == $true) { goto cleanupModes }
        mIRCd.updateChan %this.id modes $+($mIRCd.info(%this.id,modes),%this.char)
        var %this.plus = $+(%this.plus,%this.char)
        if (%this.char isincs %this.minus) { var %this.minus = $removecs(%this.minus,%this.char) }
        var %this.polar = $iif(%this.char === p,s,p)
        ; `-> Make sure that the polar opposite isn't set. +p cannot be set as well as +s.
        if ($is_modeSet(%this.id,%this.polar).chan == $true) {
          mIRCd.updateChan %this.id modes $removecs($mIRCd.info(%this.id,modes),%this.polar)
          var %this.minus = $+(%this.minus,%this.polar)
          if (%this.polar isincs %this.plus) { var %this.plus = $removecs(%this.plus,%this.polar) }
        }
        goto cleanupModes
      }
    }
    ; `-> Somebody did something like: /MODE #chan mi+v Jigsy
    if ($pos(-+,%this.char) != $null) { var %this.flag = %this.char }
    :cleanupModes
    ; `-> Deal with the string.
    if ($calc(($len(%this.minus) + $len(%this.plus)) - 2) >= $mIRCd(MODESPL)) {
      mIRCd.modeTell $1 $2 %this.id %this.plus %this.minus $iif(%this.argPlus != $null,$v1,0) ¦ $iif(%this.argMinus != $null,$v1,0)
      if (P isincs %this.minus) { inc %this.destruct 1 }
      if (P isincs %this.plus) { dec %this.destruct 1 }
      var %this.minus = -, %this.plus = +, %this.argMinus = $null, %this.argPlus = $null, %this.string = $null
    }
  }
  if ($calc(($len(%this.minus) + $len(%this.plus)) - 2) > 0) {
    ; `-> Leftovers.
    mIRCd.modeTell $1 $2 %this.id %this.plus %this.minus $iif(%this.argPlus != $null,$v1,0) ¦ $iif(%this.argMinus != $null,$v1,0)
    if (P isincs %this.minus) { inc %this.destruct 1 }
    if (P isincs %this.plus) { dec %this.destruct 1 }
  }
  if (%this.destruct > 0) {
    if ($hcount($mIRCd.chanUsers(%this.id)) == 0) { mIRCd.destroyChan %this.id }
    ; `-> Destroy the channel if officially -P.
  }
}
; ¦-> We're done! This is quite literally one of the biggest pains in the ass out of the entire codebase! (Hey, at least it works!)
; `-> 27/01/2023: I stand corrected. /WHO now officially takes the crown throne. Compared to that, this was a cakewalk.
alias mIRCd.makeDefaultModes {
  ; $mIRCd.makeDefaultModes(<input>)[.chan|user]

  if ($prop == chan) {
    if ($1 == $null) { return $+(+,$mIRCd.defaultChanModes) }
    var %this.input = $iif($1 != $null,$v1,nt), %this.modes = $gettok($mIRCd.chanModes,1,32), %this.modeArgs = $gettok($mIRCd.chanModes,2,32)
    var %this.modeArgsSplit = $left($regsubex($str(.,$len(%this.modeArgs)),/./g,$+($mid(%this.modeArgs,\n,1),$comma)),-1)
    var %this.modesLeft = $removecs(%this.modes, [ %this.modeArgsSplit ] )
    if (%this.modesLeft == $null) { return +nt }
    ; ,-> Sadly, I have to loop this instead of using a regex hack.
    var %this.loop = 0, %these.polars = pscS, %this.polar = p s,s p,c S,S c
    while (%this.loop < $len(%this.input)) {
      inc %this.loop = 1
      var %this.char = $mid(%this.input,%this.loop,1)
      if (%this.char !isincs %this.modesLeft) { continue }
      if (%this.char isincs %these.polars) {
        var %this.polarChar = $regsubex($str(.,$matchtokcs(%this.polar,%this.char,0,44)),/./g,$iif($gettok($matchtokcs(%this.polar,%this.char,\n,44),1,32) === %this.char,$gettok($matchtokcs(%this.polar,%this.char,\n,44),2,32)))
        if ((%this.polarChar isincs %this.lower) || (%this.polarChar isincs %this.upper)) { continue } 
      }
      if (%this.char isincs %this.lower) { continue }
      if (%this.char isincs %this.upper) { continue }
      if (%this.char isupper) { var %this.upper = %this.upper %this.char }
      if (%this.char islower) { var %this.lower = %this.lower %this.char }
      ; `-> OCD: $sorttok() doesn't sort lowerUPPER the way I want it. It'll do something like s S n Y y instead of n s y S Y.
    }
    return $+(+,$iif($removecs($+($sorttokcs(%this.lower,32,a),$sorttok(%this.upper,32,a)), $chr(32)) != $null,$v1,$mIRCd.defaultChanModes))
    ; `-> Default back to +nt if there isn't anything.
  }
  ; ,-> User.
  if ($1 == $null) { + }
  var %this.loop = 0, %these.polars = cS, %this.polar = c S,S c, %this.forbidden = koX
  ; `-> I don't mind the other modes being allowed (+g/+W) but I will _NOT_ allow +k, +o or +X. That's just asking for trouble.
  while (%this.loop < $len($1)) {
    inc %this.loop = 1
    var %this.char = $mid($1,%this.loop,1)
    if (%this.char !isincs $mIRCd.userModes) { continue }
    if (%this.char isincs %this.forbidden) { continue }
    if (%this.char isincs %these.polars) {
      var %this.polarChar = $regsubex($str(.,$matchtokcs(%this.polar,%this.char,0,44)),/./g,$iif($gettok($matchtokcs(%this.polar,%this.char,\n,44),1,32) === %this.char,$gettok($matchtokcs(%this.polar,%this.char,\n,44),2,32)))
      if ((%this.polarChar isincs %this.lower) || (%this.polarChar isincs %this.upper)) { continue }
    }
    if (%this.char isincs %this.lower) { continue }
    if (%this.char isincs %this.upper) { continue }
    if (%this.char isupper) { var %this.upper = %this.upper %this.char }
    if (%this.char islower) { var %this.lower = %this.lower %this.char }
  }
  return $+(+,$removecs($+($sorttok(%this.lower,32,a),$sorttok(%this.upper,32,a)), $chr(32)))
}
alias -l mIRCd.modeTell {
  ; /mIRCd.modeTell <sockname> <command> <chan ID> <plus modes> <minus modes> <plus args> ¦ <minus args>
  ;
  ; ¦ is the separator.

  if ($4 != +) { var %this.string = $v1 }
  if ($5 != -) { var %this.string = $+(%this.string,$v1) }
  if ($gettok($gettok($1-,6-,32),1,166) != 0) { var %this.string = %this.string $regsubex($str(.,$numtok($v1,32)),/./g,$+($gettok($gettok($v1,\n,32),2-,58),$chr(32))) }
  if ($gettok($gettok($1-,6-,32),2,166) != 0) { var %this.string = %this.string $regsubex($str(.,$numtok($v1,32)),/./g,$+($gettok($gettok($v1,\n,32),2-,58),$chr(32))) }
  var %this.push = 0
  while (%this.push < $hcount($mIRCd.chanUsers($3))) {
    inc %this.push 1
    mIRCd.raw $hget($mIRCd.chanUsers($3),%this.push).item $+(:,$iif($2 == OPMODE,$hget($mIRCd.temp,SERVER_NAME),$mIRCd.fulladdr($1))) MODE $mIRCd.info($3,name) %this.string
  }
}
alias mIRCd.userModes { return $+(cdgiknoswxCDIMSW,$iif($hget($mIRCd.temp,OPER_OVERRIDE) == 1,X)) }
