; mIRCd_msgHandle.mrc
;
; This script contains the following command(s): NOTICE, PRIVMSG, WALLCHOPS, WALLHOPS, WALLOPS, WALLUSERS, WALLVOICES

alias mIRCd_command_notice {
  ; /mIRCd_command_notice <sockname> NOTICE <target[,target,target,...]> :<message>

  mIRCd.parseMsg $1-
}
alias mIRCd_command_privmsg {
  ; /mIRCd_command_privmsg <sockname> PRIVMSG <target[,target,target,...]> :<message>

  mIRCd.parseMsg $1-
}
alias mIRCd_command_wallchops {
  ; /mIRCd_command_wallchops <sockname> WALLCHOPS <#chan> :<message>

  mIRCd.parseWall $1-
}
alias mIRCd_command_wallhops {
  ; /mIRCd_command_wallhops <sockname> WALLHOPS <#chan> :<message>

  mIRCd.parseWall $1-
}
alias mIRCd_command_wallops {
  ; /mIRCd_command_wallops <sockname> WALLOPS :<message>

  if ($is_oper($1) == $false) {
    mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
    return
  }
  if (($3- == :) || ($3- == $null)) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  if ($calc($len($2) + $len($3-)) > $mIRCd.maxLineLen) {
    mIRCd.sraw $1 $mIRCd.reply(417,$mIRCd.info($1,nick))
    return
  }
  var %this.loop = 0
  while (%this.loop < $hcount($mIRCd.users)) {
    inc %this.loop 1
    var %this.sock = $hget($mIRCd.users,%this.loop).item
    if (($is_oper(%this.sock) == $true) && ($is_modeSet(%this.sock,w).nick == $true)) { mIRCd.raw %this.sock $+(:,$mIRCd.fulladdr($1)) WALLOPS :* $decolonize($3-) }
    ; `-> Only display to oper(s).
  }
}
alias mIRCd_command_wallusers {
  ; /mIRCd_command_wallusers <sockname> WALLUSERS :<message>

  if ($is_oper($1) == $false) {
    mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
    return
  }
  if (($3- == :) || ($3- == $null)) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  if ($calc($len($2) + $len($3-)) > $mIRCd.maxLineLen) {
    mIRCd.sraw $1 $mIRCd.reply(417,$mIRCd.info($1,nick))
    return
  }
  var %this.loop = 0
  while (%this.loop < $hcount($mIRCd.users)) {
    inc %this.loop 1
    var %this.sock = $hget($mIRCd.users,%this.loop).item
    if ($is_modeSet(%this.sock,w).nick == $true) { mIRCd.raw %this.sock $+(:,$mIRCd.fulladdr($1)) WALLOPS $+(:,$dollar) $decolonize($3-) }
  }
}
; `-> TODO: Also combine WALLOPS and WALLUSERS into one?
alias mIRCd_command_wallvoices {
  ; /mIRCd_command_wallvoices <sockname> WALLVOICES <#chan> :<message>

  mIRCd.parseWall $1-
}

; Commands and Functions

alias mIRCd.maxLineLen { return 512 }
; `-> WARNING(!): DO *NOT* CHANGE THIS!
alias mIRCd.parseMsg {
  ; /mIRCd.parseMsg <args>

  if ($3 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(411,$mIRCd.info($1,nick),$2)
    return
  }
  if (($4- == :) || ($4- == $null)) {
    mIRCd.sraw $1 $mIRCd.reply(412,$mIRCd.info($1,nick),$2)
    return
  }
  mIRCd.updateUser $1 idleTime $ctime
  ; `-> Update their idleTime. It doesn't matter if the message goes through or not.
  var %this.targets = $3
  if ($mIRCd(MAXTARGETS) isnum 1-) {
    ; `-> NOTE: This trumps TARGMAX_NOTICE/TARGMAX_PRIVMSG.
    var %this.targets = $deltok(%this.targets,$+($calc($v1 + 1),-),44), %this.flag = 1
  }
  if ((%this.flag != 1) && ($hget($mIRCd.targMax,$+(TARGMAX_,$2)) isnum 1-)) { var %this.targets = $deltok(%this.targets,$+($calc($v1 + 1),-),44) }
  if (%this.targets == $null) {
    mIRCd.sraw $1 $mIRCd.reply(411,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.loop = 0, %this.message = $4-
  while (%this.loop < $numtok(%this.targets,44)) {
    inc %this.loop 1
    var %this.target = $gettok(%this.targets,%this.loop,44), %skip.error = 0
    if ($istok($gettok(%this.targets,$+($calc(%this.loop - 1),--),44),%this.target,44) == $true) { continue }
    ; `-> Send the message to the target once, and only once. Otherwise NOTICE|PRIVMSG #chan,#chan,#chan Hi! would annoyingly show "Hi!" in #chan three times.
    if ($is_valid(%this.target).chan == $true) {
      if ($is_exists(%this.target).chan == $false) {
        mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),%this.target)
        continue
      }
      var %this.id = $getChanID(%this.target), %this.name = $mIRCd.info(%this.id,name)
      if ($calc($len($2) + $len(%this.name) + $len($4-)) > $mIRCd.maxLineLen) {
        ; `-> NOTE TO SELF(!): Is this even right?
        mIRCd.sraw $1 $mIRCd.reply(417,$mIRCd.info($1,nick))
        continue
      }
      if ($is_modeSet($1,X).nick == $true) { goto parsePublic }
      if (($is_modeSet(%this.id,n).chan == $true) && ($is_on(%this.id,$1) == $false)) {
        if (($is_secret(%this.id) == $true) && ($bool_fmt($mIRCd(DENY_SECRET)) == $true)) {
          mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),%this.target)
          continue
        }
        mIRCd.sraw $1 $mIRCd.reply(404,$mIRCd.info($1,nick),%this.name) (No external messages (+n))
        continue
      }
      if (($is_modeSet(%this.id,T).chan == $true) && ($numtok(%this.targets,44) > 1)) {
        mIRCd.sraw $1 $mIRCd.reply(404,$mIRCd.info($1,nick),%this.name) (No multi-target messages (+T))
        continue
      }
      if (($is_modeSet(%this.id,C).chan == $true) && ($2 == PRIVMSG) && ($+($chr(1),*,$chr(1)) iswm $decolonize(%this.message)) && ($+($chr(1),ACTION *,$chr(1)) !iswm $decolonize(%this.message))) {
        mIRCd.sraw $1 $mIRCd.reply(404,$mIRCd.info($1,nick),%this.name) (/CTCP is not allowed (+C))
        continue
      }
      if (($is_op(%this.id,$1) == $true) || ($is_hop(%this.id,$1) == $true)) { goto parsePublic }
      if (($is_modeSet(%this.id,N).chan == $true) && ($2 == NOTICE)) {
        mIRCd.sraw $1 $mIRCd.reply(404,$mIRCd.info($1,nick),%this.name) (/NOTICE is not allowed (+N))
        continue
      }
      if ($is_voice(%this.id,$1) == $true) { goto parsePublic }
      if (($is_banMatch(%this.id,$mIRCd.fulladdr($1)) == $true) || ($is_banMatch(%this.id,$mIRCd.ipaddr($1)) == $true) || ($is_banMatch(%this.id,$mIRCd.trueaddr($1)) == $true)) {
        mIRCd.sraw $1 $mIRCd.reply(404,$mIRCd.info($1,nick),%this.name) (Cannot talk while banned (+b))
        continue
      }
      if ($is_modeSet(%this.id,m).chan == $true) {
        mIRCd.sraw $1 $mIRCd.reply(404,$mIRCd.info($1,nick),%this.name) (Channel is moderated (+m))
        continue
      }
      if ($is_modeSet(%this.id,g).chan == $true) {
        var %this.timestamp = $iif($gettok($hget($mIRCd.chanUsers(%this.id),$1),1,32) != $null,$v1,$ctime)
        if ($calc($ctime - %this.timestamp) <= $mIRCd.info(%this.id,gagTime)) {
          mIRCd.sraw $1 $mIRCd.reply(404,$mIRCd.info($1,nick),%this.name) (Gagged: Please wait $calc($mIRCd.info(%this.id,gagTime) - $calc($ctime - %this.timestamp)) seconds (+g))
          continue
        }
      }
      if (($is_modeSet(%this.id,c).chan == $true) && ($+(*,$chr(3),*) iswm %this.message)) {
        ; `-> Just block the use of color. Bold, underline, etc. is okay.
        mIRCd.sraw $1 $mIRCd.reply(404,$mIRCd.info($1,nick),%this.name) (No colors allowed (+c))
        continue
      }
      if ($is_modeSet(%this.id,S).chan == $true) { var %this.message = $strip(%this.message) }
      :parsePublic
      var %this.userLoop = 0, %this.changeState = 0
      while (%this.userLoop < $hcount($mIRCd.chanUsers(%this.id))) {
        inc %this.userLoop 1
        var %this.sock = $hget($mIRCd.chanUsers(%this.id),%this.userLoop).item
        if (%this.sock == $1) { continue }
        ; `-> We don't need to see our own message. We see it when we send it.
        if ($gettok($hget($mIRCd.chanUsers(%this.id),$1),2,32) == 1) {
          mIRCd.raw %this.sock $+(:,$mIRCd.fulladdr($1)) JOIN $mIRCd.info(%this.id,name)
          var %this.changeState = 1
        }
        if ($is_modeSet($1,X).nick == $true) { goto skipTheseSettings }
        if ($is_modeSet(%this.sock,d).nick == $true) { continue }
        ; `-> +d(eaf) users live up to their name.
        if ($is_silenceMatch(%this.sock,$mIRCd.fulladdr($1)) == $true) { continue }
        ; `-> Note to self: The lack of ipaddr and trueaddr is not a bug. (Although if anyone raises this as an issue on Github, change it.)
        if ($is_modeSet(%this.id,B).chan == $true) {
          if ($iif($mIRCd.info(%this.sock,idleTime) != $null,$calc($ctime - $v1),$sock(%this.sock).to) >= $mIRCd.info(%this.id,bandwidth)) { continue }
        }
        :skipTheseSettings
        mIRCd.raw %this.sock $+(:,$mIRCd.fulladdr($1)) $upper($2) %this.name $colonize(%this.message)
        ; `-> Note to self: Should certain user settings be taken into consideration here? Like /SILENCE?
      }
      if (%this.changeState == 1) {
        mIRCd.updateChanUser %this.id $1 0 2
        if ($is_modeSet(%this.id,d).chan == $true) { mIRCd.dCheck %this.id }
      }
      mIRCd.updateChan %this.id lastActive $ctime
      continue
    }
    ; ,-> The target is a user?
    if ($is_exists(%this.target).nick == $false) {
      if ($left(%this.target,1) == $chr(36)) {
        ; ¦-> Send a message to everybody online. $* would send a message to everyone, $*.localhost would send a message to everyone on a
        ; ¦-> server ending in *.localhost, $*.org would send a message to everyone on a server ending in *.org, etc.
        ; ¦-> And yes, /msg $*,*.localhost is allowed. $*,$* would follow the "no previous targets" restriction, but $*,$*.localhost 
        ; ¦-> are viewed as two different targets. However, that doesn't seem to work on this. It drops everything after the first.
        ; ¦-> So /msg $*,$*.localhost,Jigsy would drop $*.localhost and Jigsy. I'm guessing this is something mIRC related.
        ; ¦
        ; `-> I'll see if I can find some way to fix this, though... (No promises!)
        if ($is_oper($1) == $false) {
          mIRCd.sraw $1 $mIRCd.reply(401,$mIRCd.info($1,nick),%this.target)
          continue
        }
        var %this.server = $right(%this.target,-1)
        if (%this.server !iswm $mIRCd.temp(SERVER_NAME).temp) {
          mIRCd.sraw $1 $mIRCd.reply(401,$mIRCd.info($1,nick),%this.target)
          continue
        }
        var %this.loop = 0
        while (%this.loop < $hcount($mIRCd.users)) {
          inc %this.loop 1
          var %this.globalSock = $hget($mIRCd.users,%this.loop).item
          mIRCd.raw %this.globalSock $+(:,$mIRCd.fulladdr($1)) $upper($2) %this.target $colonize(%this.message)
        }
        continue
      }
      if ($count(%this.target,@) > 0) {
        var %this.server = $gettok(%this.target,2,64)
        if (%this.server != $mIRCd(SERVER_NAME).temp) {
          mIRCd.sraw $1 $mIRCd.reply(401,$mIRCd.info($1,nick),%this.target)
          continue
        }
        var %this.serverTarget = $getSockname($gettok(%this.target,1,64))
        if (%this.serverTarget != $null) {
          var %this.target = $gettok(%this.target,1,64)
          var %skip.error = 1
        }
      }
      if (%skip.error != 1) {
        mIRCd.sraw $1 $mIRCd.reply(401,$mIRCd.info($1,nick),%this.target)
        continue
      }
    }
    var %this.sock = $getSockname($gettok(%this.target,1,64)), %this.nick = $mIRCd.info(%this.sock,nick)
    if ($1 == %this.sock) { goto parsePrivate }
    if ($is_oper($1) == $true) { goto preParsePrivate }
    if (($is_modeSet(%this.sock,c).nick == $true) && ($+(*,$chr(3),*) iswm %this.message)) {
      mIRCd.sraw $1 $mIRCd.reply(599,$mIRCd.info($1,nick),%this.nick) (This user blocks colors (+c))
      continue
    }
    if ($is_modeSet(%this.sock,D).nick == $true) {
      mIRCd.sraw $1 $mIRCd.reply(487,$mIRCd.info($1,nick),%this.nick)
      continue
    }
    if ($is_modeSet(%this.sock,m).nick == $true) {
      if (($is_acceptMatch(%this.sock,$mIRCd.fulladdr($1)) == $false) || ($is_acceptMatch(%this.sock,$mIRCd.ipaddr($1)) == $false) || ($is_acceptMatch(%this.sock,$mIRCd.trueaddr($1)) == $false)) {
        mIRCd.sraw $1 $mIRCd.reply(599,$mIRCd.info($1,nick),%this.nick) (This user denies messages from those not on their /ACCEPT list (+m))
        continue
      }
    }
    if (($is_modeSet(%this.sock,M).nick == $true) && ($is_mutual(%this.sock,$1) == $false)) {
      mIRCd.sraw $1 $mIRCd.reply(599,$mIRCd.info($1,nick),%this.nick) (You are not on a mutual channel (+M))
      continue
    }
    if (($is_modeSet(%this.sock,C).nick == $true) && ($+($chr(1),*,$chr(1)) iswm $decolonize(%this.message)) && ($+($chr(1),ACTION *,$chr(1)) !iswm $decolonize(%this.message))) {
      mIRCd.sraw $1 $mIRCd.reply(599,$mIRCd.info($1,nick),%this.nick) (This user denies /CTCP requests (+C))
      continue
    }
    if (($is_blockMatch(%this.sock,$mIRCd.fulladdr($1)) == $true) || ($is_blockMatch(%this.sock,$mIRCd.ipaddr($1)) == $true) || ($is_blockMatch(%this.sock,$mIRCd.trueAddr($1)) == $true)) {
      mIRCd.sraw $1 $mIRCd.reply(599,$mIRCd.info($1,nick),%this.nick) (This user denies messages from those on their /BLOCK list)
      continue
    }
    :preParsePrivate
    ; >-> Even though we've skipped the above if they're an oper, IRC opers still adhere to this unless usermode +X.
    if ($is_modeSet(%this.sock,S).nick == $true) {
      if ($is_modeSet($1,X).nick == $false) { var %this.message = $strip(%this.message) }
    }
    if ($is_silenceMatch(%this.sock,$mIRCd.fulladdr($1)) == $true) {
      if ($is_modeSet($1,X).nick == $false) { continue }
    }
    :parsePrivate
    if ($calc($len($2) + $len($mIRCd.info(%this.sock,nick)) + $len($4-)) > $mIRCd.maxLineLen) {
      mIRCd.sraw $1 $mIRCd.reply(417,$mIRCd.info($1,nick))
      continue
    }
    if ($mIRCd.info(%this.sock,away) != $null) { mIRCd.sraw $1 $mIRCd.reply(301,$mIRCd.info($1,nick),$mIRCd.info(%this.sock,nick),$mIRCd.info(%this.sock,away)) }
    mIRCd.raw %this.sock $+(:,$mIRCd.fulladdr($1)) $upper($2) %this.nick $colonize(%this.message)
  }
}
alias mIRCd.parseWall {
  ; /mIRCd.parseWall <args>

  if (($4- == :) || ($4- == $null)) {
    mIRCd.sraw $1 $mIRCd.reply(412,$mIRCd.info($1,nick))
    return
  }
  if ($is_exists($3).chan == $false) {
    mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),$3)
    return
  }
  var %this.id = $getChanID($3), %this.name = $mIRCd.info(%this.id,name)
  if (($is_on(%this.id,$1) == $false) && ($is_modeSet(%this.id,n).chan == $true)) {
    if ($is_modeSet($1,X).nick == $true) { goto parseWallmsg }
    if (($is_secret(%this.id) == $true) && ($bool_fmt($mIRCd(DENY_SECRET)) == $true)) {
      mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),$3)
      return
    }
    mIRCd.sraw $1 $mIRCd.reply(404,$mIRCd.info($1,nick),%this.name) (No external messages (+n))
    return
  }
  if ($calc($len($2) + $len(%this.name) + $len($4-)) > $mIRCd.maxLineLen) {
    mIRCd.sraw $1 $mIRCd.reply(417,$mIRCd.info($1,nick))
    return
  }
  :parseWallmsg
  var %this.flag = $eval(%,0) WALLHOPS,@ WALLCHOPS,+ WALLVOICES
  var %this.loop = 0, %this.string = $+(:,$gettok($matchtok(%this.flag,$2,1,44),1,32)) $4-
  while (%this.loop < $hcount($mIRCd.chanUsers(%this.id))) {
    inc %this.loop 1
    var %this.sock = $hget($mIRCd.chanUsers(%this.id),%this.loop).item
    if (%this.sock == $1) { continue }
    if ($is_silenceMatch(%this.sock,$mIRCd.fulladdr($1)) == $true) { continue }
    if (($2 == WALLVOICES) && ($is_regUser(%this.id,%this.sock) == $true)) { continue }
    if (($2 == WALLHOPS) && ($is_op(%this.id,%this.sock) == $false) && ($is_hop(%this.id,%this.sock) == $false)) { continue }
    if (($2 == WALLCHOPS) && ($is_op(%this.id,%this.sock) == $false)) { continue }
    mIRCd.raw %this.sock $+(:,$mIRCd.fulladdr($1)) NOTICE $+(@,$3) %this.string
    if (%this.activeFlag != 1) { var %this.activeFlag = 1 }
  }
  if (%this.activeFlag == 1) { mIRCd.updateChan %this.id lastActive $ctime }
}
alias mIRCd.serverWallops {
  ; /mIRCd.serverWallops <text>

  if ($1- = $null) { return }
  if ($hcount($mIRCd.users) == 0) { return }
  var %this.loop = 0
  while (%this.loop < $hcount($mIRCd.users)) {
    inc %this.loop 1
    var %this.sock = $hget($mIRCd.users,%this.loop).item
    if ($is_modeSet(%this.sock,g).nick == $false) { continue }
    mIRCd.sraw %this.sock WALLOPS $+(:,$1-)
  }
}
; `-> This is basically a desynch wallops (+g).

; EOF
