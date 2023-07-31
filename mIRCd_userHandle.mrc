; mIRCd_userHandle.mrc
;
; This script contains the following command(s): CLOSE, ERROR, KILL, NICK, PASS, PING, PONG, POST, QUIT, USER, SVSNICK

alias mIRCd_command_close {
  ; /mIRCd_command_close <sockname> CLOSE

  if ($is_oper($1) == $false) {
    mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
    return
  }
  if ($hcount($mIRCd.unknown) == 0) {
    mIRCd.sraw $1 NOTICE $mIRCd.info($1,nick) :Closed 0 connection(s)...
    return
  }
  var %this.count = $hcount($mIRCd.unknown), %this.loop = %this.count
  while (%this.loop > 0) {
    var %this.sock = $hget($mIRCd.unknown,%this.loop).item
    mIRCd.errorUser %this.sock $mIRCd.closeConnection
    dec %this.loop 1
  }
  mIRCd.sraw $1 NOTICE $mIRCd.info($1,nick) :Closed %this.count connection(s)...
}
alias mIRCd_command_error { noop }
; `-> noop by design.
alias mIRCd_command_kill {
  ; /mIRCd_command_kill <sockname> KILL <nick> :<reason>

  if ($is_oper($1) == $false) {
    mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
    return
  }
  if (($4- == :) || ($4- == $null)) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  if ($3 == $mIRCd(SERVER_NAME).temp) {
    mIRCd.sraw $1 $mIRCd.reply(483,$mIRCd.info($1,nick))
    return
  }
  if ($getSockname($3) == $null) {
    mIRCd.sraw $1 $mIRCd.reply(401,$mIRCd.info($1,nick),$3)
    return
  }
  var %this.sock = $getSockname($3)
  if ($is_modeSet(%this.sock,k).nick == $true) {
    mIRCd.sraw $1 $mIRCd.reply(484,$mIRCd.info($1,nick),$mIRCd.info(%this.sock,nick))
    return
  }
  mIRCd.raw %this.sock $+(:,$mIRCd.fulladdr($1)) KILL $mIRCd.info(%this.sock,nick) $colonize($4-)
  mIRCd.errorUser %this.sock Killed $parenthesis($mIRCd.info($1,nick) $parenthesis($decolonize($colonize($4-))))
  mIRCd.serverNotice 4 Received $upper($2) message for $mIRCd.info(%this.sock,nick) $parenthesis($gettok($mIRCd.fulladdr(%this.sock),2,33)) from $mIRCd.info($1,nick) $parenthesis($decolonize($colonize($4-)))
}
alias mIRCd_command_nick {
  ; /mIRCd_command_nick <sockname> NICK [:]<nick>

  var %this.current = $iif($mIRCd.info($1,nick) != $null,$v1,*)
  if (($3 == :) || ($3 == $null)) {
    mIRCd.sraw $1 $mIRCd.reply(431,%this.current,$2)
    return
  }
  var %this.nick = $left($decolonize($3),$mIRCd(MAXNICKLEN))
  if ($is_valid(%this.nick).nick == $false) {
    mIRCd.sraw $1 $mIRCd.reply(432,%this.current,%this.nick)
    return
  }
  if ($is_badNick(%this.nick) == $true) {
    mIRCd.sraw $1 $mIRCd.reply(432,%this.current,%this.nick)
    ; `-> Just go with "erroneous nick."
    return
  }
  if ($is_exists(%this.nick).nick == $true) {
    if ($getSockname(%this.nick) != $1) { mIRCd.sraw $1 $mIRCd.reply(433,%this.current,%this.nick) }
    ; `-> We don't need to inform us of this if it's us.
    return
  }
  var %this.fulladdr = $mIRCd.fulladdr($1), %this.ipaddr = $mIRCd.ipaddr($1), %this.trueaddr = $mIRCd.trueaddr($1)
  if ($mIRCd.info($1,isReg) == 0) {
    mIRCd.mapNick $1 %this.nick $ctime
    if ($mIRCd.info($1,realName) != $null) { mIRCd.registerUser $1 }
    return
  }
  if ($calc($ctime - $iif($mIRCd.info($1,nickTime) != $null,$v1,$ctime)) < $mIRCd(NICK_CHANGE_THROTTLE)) {
    var %this.time = $calc($mIRCd(NICK_CHANGE_THROTTLE) - $v1)
    mIRCd.raw $1 $mIRCd.reply(438,%this.current,%this.nick,%this.time)
    return
  }
  var %this.chans = $mIRCd.info($1,chans)
  if (%this.chans == $null) {
    mIRCd.mapNick $1 %this.nick $ctime
    mIRCd.raw $1 $+(:,%this.fulladdr) NICK $+(:,%this.nick)
    ; `-> Just inform the user.
    return
  }
  var %this.chan = 0
  while (%this.chan < $numtok(%this.chans,44)) {
    inc %this.chan 1
    var %this.id = $gettok(%this.chans,%this.chan,44)
    if (($is_modeSet(%this.id,m).chan == $true) || ($is_banMatch(%this.id,%this.fulladdr) == $true) || ($is_banMatch(%this.id,%this.ipaddr) == $true) || ($is_banMatch(%this.id,%this.trueaddr) == $true)) {
      if ($is_regUser(%this.id,$1) == $true) {
        mIRCd.sraw $1 $mIRCd.reply(437,%this.current,$mIRCd.info(%this.id,name))
        return
      }
      ; `-> Can't change nick when banned on a channel or the channel is moderated. (Unless they're +v or above.)
    }
  }
  mIRCd.mapNick $1 %this.nick $ctime
  var %this.loop = 0
  while (%this.loop < $hcount($mIRCd.users)) {
    inc %this.loop 1
    var %this.sock = $hget($mIRCd.users,%this.loop).item
    if ($is_mutualHidden($1,%this.sock) == $true) {
      if ($1 != %this.sock) { continue }
    }
    mIRCd.raw %this.sock $+(:,%this.fulladdr) NICK $+(:,%this.nick)
  }
}
alias mIRCd_command_pass {
  ; /mIRCd_command_pass <sockname> PASS :[password]

  if ($mIRCd.info($1,isReg) == 1) {
    mIRCd.sraw $1 $mIRCd.reply(462,$mIRCd.info($1,nick))
    return
  }
  var %this.current = $iif($mIRCd.info($1,nick) != $null,$v1,*)
  if ($3 == $null) {
    ; `-> Just $3 being null. Apparently : itself is okay as a password. (Empty password perhaps?)
    mIRCd.sraw $1 $mIRCd.reply(461,%this.current,$2)
    return
  }
  mIRCd.updateUser $1 password $mIRCd.encryptPass($decolonize($3))
}
; `-> This command must come *BEFORE* NICK and USER. There isn't a limit on how many times it can be used, either.
alias mIRCd_command_ping {
  ; /mIRCd_command_ping <sockname> PING :<arg>

  if (($3 == :) || ($3 == $null)) {
    mIRCd.sraw $1 $mIRCd.reply(409,$iif($mIRCd.info($1,nick) != $null,$v1,*),$2)
    return
  }
  mIRCd.raw $1 PONG $colonize($3)
  mIRCd.updateUser $1 lastPing $ctime
}
alias mIRCd_command_pong {
  ; /mIRCd_command_pong <sockname> PONG :<arg>

  var %this.current = $iif($mIRCd.info($1,nick) != $null,$v1,*)
  if (($3 == :) || ($3 == $null)) {
    if ($mIRCd.info($1,isReg) == 0) {
      mIRCd.sraw $1 $mIRCd.reply(461,%this.current,$2)
      return
    }
    mIRCd.updateUser $1 lastPing $ctime
    return
  }
  if ($mIRCd.info($1,isReg) == 1) {
    mIRCd.updateUser $1 lastPing $ctime
    return
  }
  if ($3 !=== $+(:,$mIRCd.info($1,passPing))) {
    mIRCd.sraw $1 $mIRCd.reply(513,%this.current,$mIRCd.info($1,passPing))
    return
  }
  var %this.realName = $+(!R,$strip($mIRCd.info($1,realName)))
  if (($is_klineMatch($mIRCd.ipaddr($1)) == $true) || ($is_klineMatch($mIRCd.trueaddr($1)) == $true) || ($is_klineMatch(%this.realName) == $true)) {
    if ($hfind($mIRCd.klines,$mIRCd.ipaddr($1),1,W) != $null) { var %this.data = $v1 }
    if ($hfind($mIRCd.klines,$mIRCd.trueaddr($1),1,W) != $null) { var %this.data = $v1 }
    ; `-> fulladdr and trueaddr and this are pretty much identical at this point of processing.
    var %this.match = $hget($mIRCd.klines,%this.data)
    if ($is_klineMatch(%this.realName) == $true) { var %this.match = $hget($mIRCd.klines,$hfind($mIRCd.klines,%this.realName,1,W)) }
    mIRCd.sraw $1 $mIRCd.reply(465,%this.current,%this.match)
    $+(.timermIRCd.kline,$1) -o 1 0 mIRCd.errorUser $1 K-lined $parenthesis(%this.match)
    return
  }
  if (($is_zlineMatch($sock($1).ip) == $true) || ($is_zlineMatch($sock($1).ip).local == $true)) {
    if ($hfind($mIRCd.zlines,$sock($1).ip,1,W) != $null) { var %this.match = $gettok($hget($mIRCd.zlines,$hfind($mIRCd.zlines,$sock($1).ip,1,W)),2-,32) }
    if ($hfind($mIRCd.local(Zlines),$sock($1).ip,1,W) != $null) { var %this.match = $hget($mIRCd.local(Zlines),$hfind($mIRCd.local(Zlines),$sock($1).ip,1,W)) }
    mIRCd.sraw $1 $mIRCd.reply(465,%this.current,%this.match)
    $+(.timermIRCd.zline,$1) -o 1 0 mIRCd.errorUser $1 Z-lined $parenthesis(%this.match)
    return
  }
  if (($is_glineMatch($mIRCd.ipaddr($1)) == $true) || ($is_glineMatch($mIRCd.trueaddr($1)) == $true) || ($is_glineMatch(%this.realName) == $true)) {
    if ($hfind($mIRCd.glines,$mIRCd.ipaddr($1),1,W) != $null) { var %this.data = $v1 }
    if ($hfind($mIRCd.glines,$mIRCd.trueaddr($1),1,W) != $null) { var %this.data = $v1 }
    ; `-> fulladdr and trueaddr and this are pretty much identical at this point of processing.
    var %this.match = $gettok($hget($mIRCd.glines,%this.data),2-,32)
    if ($is_glineMatch(%this.realName) == $true) { var %this.match = $gettok($hget($mIRCd.glines,$hfind($mIRCd.glines,%this.realName,1,W)),2-,32) }
    mIRCd.sraw $1 $mIRCd.reply(465,%this.current,%this.match)
    $+(.timermIRCd.gline,$1) -o 1 0 mIRCd.errorUser $1 G-lined $parenthesis(%this.match)
    return
  }
  ; `-> K-line takes priority (because it's local), but there's no specific order to Z-line or G-line. (03/02/2023: Now with local Z-lines, Z-line takes priority over G-line.)
  if ((127.* iswm $sock($1).ip) || (192.168.* iswm $sock($1).ip)) {
    if ($bool_fmt($mIRCd(LOCAL_IMMUNITY)) == $true) {
      mIRCd.welcome $1
      return
    }
  }
  ; `-> Allow localhost and LAN to override the rest of the code. (Though now that I think about it, do they need to be subjected to network bans?)
  if ($mIRCd(CONNECTION_PASS) != $null) {
    if ($mIRCd.info($1,firstCommand) != PASS) {
      ; `-> PASS needs to be sent *BEFORE* NICK and USER.
      $+(.timermIRCd.passNotFirst,$1) -o 1 0 mIRCd.errorUser $1 $mIRCd.badCreds(Sent $upper($mIRCd.info($1,firstCommand)) before PASS.)
      return
    }
    if ($mIRCd.info($1,password) !== $mIRCd(CONNECTION_PASS)) {
      ; `-> !== because of "magic hashes."
      $+(.timermIRCd.wrongPass,$1) -o 1 0 mIRCd.errorUser $1 $mIRCd.badCreds(Incorrect password.)
      return
    }
  }
  if ($bool_fmt($mIRCd(DENY_EXTERNAL_CONNECTIONS)) == $true) {
    if (127.* !iswm $sock($1).ip) {
      ; `-> This one doesn't need to apply to localhost. (We might want to restrict LAN, though.)
      $+(.timermIRCd.deny,$1) -o 1 0 mIRCd.errorUser $1 $mIRCd.noMore(No external connections.)
      return
    }
  }
  if ($mIRCd(MAXCLONES) isnum 1-) {
    var %this.loop = 0, %this.count = 0
    while (%this.loop < $hcount($mIRCd.users)) {
      inc %this.loop 1
      var %this.sock = $hget($mIRCd.users,%this.loop).item
      if ($1 == %this.sock) { continue }
      if ($sock($1).ip == $sock(%this.sock).ip) { inc %this.count 1 }
      if (%this.count >= $mIRCd(MAXCLONES)) {
        $+(.timermIRCd.maxClone,$1) -o 1 0 mIRCd.errorUser $1 $mIRCd.noMore(Too many from your host.)
        return
      }
    }
  }
  if ($mIRCd(MAX_USERS) isnum 1-) {
    if ($calc($hcount($mIRCd.users) - $hcount($mIRCd.unknown)) >= $mIRCd(MAX_USERS)) {
      $+(.timermIRCd.full,$1) -o 1 0 mIRCd.errorUser $1 $mIRCd.noMore(The server is full.)
      return
    }
  }
  mIRCd.welcome $1
}
alias mIRCd_command_post {
  ; /mIRCd_command_post <sockname> POST [args]

  if ($mIRCd.info($1,isReg) == 1) { return }
  mIRCd.destroyUser $1
}
; `-> This just needs to disconnect the unregistered user. Nothing else.
alias mIRCd_command_quit {
  ; /mIRCd_command_quit <sockname> QUIT :[quit message]

  mIRCd.destroyUser $1 $colonize($3-)
}
alias mIRCd_command_user {
  ; /mIRCd_command_user <sockname> USER <user> <null> <null> :<real name>

  var %this.current = $iif($mIRCd.info($1,nick) != $null,$v1,*)
  if ($mIRCd.info($1,realName) != $null) {
    mIRCd.sraw $1 $mIRCd.reply(462,%this.current)
    return
  }
  if (($6- == :) || ($6- == $null)) {
    mIRCd.sraw $1 $mIRCd.reply(461,%this.current,$2)
    return
  }
  mIRCd.updateUser $1 user $+(~,$left($legalizeIdent($3),$calc($mIRCd.userLen - 1)))
  mIRCd.updateUser $1 trueUser $left($legalizeIdent($3),$mIRCd.userLen)
  ; ¦-> 15/01/2023: There was a reason for me to add this, but I forgot what for at this juncture.
  ; `-> I just know it had to do with the user being truncated by -1, and no way of telling that against something.
  mIRCd.updateUser $1 realName $left($decolonize($6-),50)
  ; `-> Note: Control codes count towards real name length.
  if ($mIRCd.info($1,nick) != $null) { mIRCd.registerUser $1 }
}
alias mIRCd_command_svsnick {
  ; /mIRCd_command_svsnick <sockname> SVSNICK <nick> <new nick>

  if ($is_oper($1) == $false) {
    mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
    return
  }
  if ($4 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  if ($is_exists($3).nick == $false) {
    mIRCd.sraw $1 $mIRCd.reply(401,$mIRCd.info($1,nick),$3)
    return
  }
  if ($is_badNick($3) == $true) {
    mIRCd.sraw $1 $mIRCd.reply(432,$mIRCd.info($1,nick),$4)
    return
  }
  if ($is_valid($4).nick == $false) {
    mIRCd.sraw $1 $mIRCd.reply(432,$mIRCd.info($1,nick),$4)
    return
  }
  if ($is_exists($4).nick == $true) {
    if ($getSockname($4) == $1) { return }
    ; `-> Do nothing if it's us.
    mIRCd.sraw $1 $mIRCd.reply(433,$mIRCd.info($1,nick),$mIRCd.info($getSockname($4),nick))
    return
  }
  var %this.sock = $getSockname($3), %this.nick = $mIRCd.info(%this.sock,nick), %this.time = $mIRCd.info(%this.sock,nickTime)
  ; `-> Set the time as the last time they changed their nick naturally so they're not subjected to "Nick change too fast!"
  var %this.loop = 0
  while (%this.loop < $hcount($mIRCd.users)) {
    inc %this.loop 1
    var %this.otherSock = $hget($mIRCd.users,%this.loop).item
    if ($is_mutualHidden(%this.sock,%this.otherSock) == $true) {
      if (%this.sock != %this.otherSock) { continue }
    }
    mIRCd.raw %this.otherSock $+(:,$mIRCd.fulladdr(%this.sock)) NICK $+(:,$4)
  }
  mIRCd.mapNick %this.sock $4 %this.time
  mIRCd.serverWallops $upper($2) by $mIRCd.info($1,nick) $+($parenthesis($gettok($mIRCd.fulladdr($1),2,33)),:) %this.nick -> $4
  ; `-> Issue a +g wallops to prevent abuse.
}

; Commands and Functions

alias getSockname {
  ; $getSockname(<nick>)

  return $hfind($mIRCd.users,$1,1,W).data
}
alias is_badNick {
  ; $is_badNick(<nick>)

  return $iif($hfind($mIRCd.badNicks,$1,0,W).data > 0,$true,$false)
}
alias is_exists {
  ; $is_exists(<arg>)<.chan|.nick>

  if ($prop == chan) { return $iif($hfind($mIRCd.chans,$1,1,W).data != $null,$true,$false) }
  if ($prop == nick) { return $iif($hfind($mIRCd.users,$1,1,W).data != $null,$true,$false) }
}
alias legalizeIdent { return $regsubex($1,/([^a-zA-Z0-9_.-])/gu,_) }
alias mIRCd.mapNick {
  ; /mIRCd.mapNick <sockname> <nick> <last nick change>

  mIRCd.updateUser $1 nick $2
  mIRCd.updateUser $1 nickTime $iif($3 != $null,$v1,$ctime)
  hadd -m $mIRCd.users $1 $2
}
alias mIRCd.welcome {
  ; /mIRCd.welcome <sockname>

  mIRCd.serverNotice 16384 Client connecting: $mIRCd.info($1,nick) $parenthesis($gettok($mIRCd.fulladdr($1),2,33)) $bracket($sock($1).ip) $bracket($+($mIRCd.info($1,realName),))
  if (($is_shunMatch($mIRCd.fulladdr($1)) == $true) || ($is_shunMatch($mIRCd.ipaddr($1)) == $true) || ($is_shunMatch($mIRCd.trueaddr($1)) == $true) || ($is_shunMatch($+(!R,$strip($mIRCd.info($1,realName)))) == $true) || ($is_shunMatch($mIRCd.fulladdr($1)).local == $true) || ($is_shunMatch($mIRCd.ipaddr($1)).local == $true) || ($is_shunMatch($mIRCd.trueaddr($1)).local == $true) || ($is_shunMatch($+(!R,$strip($mIRCd.info($1,realName)))).local == $true)) {
    mIRCd.serverNotice 512 Shun active for $mIRCd.info($1,nick) $parenthesis($gettok($mIRCd.fulladdr($1),2,33))
    ; `-> Putting this here because the previous line is long enough as it is.
  }
  ; `-> If, for some reason, people aren't registering, comment the entire SHUN section out.
  mIRCd.updateUser $1 isReg 1
  ; `-> The user is now officially registered with the IRCd! (Yay!)
  hdel $mIRCd.unknown $1
  mIRCd.delUserItem $1 firstCommand
  mIRCd.delUserItem $1 dnsChecked
  mIRCd.delUserItem $1 identChecked
  mIRCd.delUserItem $1 passPing
  mIRCd.delUserItem $1 password
  ; `-> No longer needed.
  mIRCd.updateUser $1 lastPing $ctime
  mIRCd.updateUser $1 snoMask $mIRCd(DEFAULT_SNOMASK)
  mIRCd.updateUser $1 NAMESX 1
  mIRCd.updateUser $1 UHNAMES 1
  if ($calc($hcount($mIRCd.users) - $hcount($mIRCd.unknown)) > $mIRCd(highCount).temp) { hadd -m $mIRCd.temp highCount $v1 }
  ; `-> TBC: Does the highCount include connecting users?
  mIRCd.sraw $1 $mIRCd.reply(001,$mIRCd.info($1,nick),$mIRCd.fulladdr($1))
  mIRCd.sraw $1 $mIRCd.reply(002,$mIRCd.info($1,nick))
  mIRCd.sraw $1 $mIRCd.reply(003,$mIRCd.info($1,nick),$calc($ctime - $iif($mIRCd(startTime).temp != $null,$calc($ctime - $v1),$sock($mIRCd.info($1,thruSock)).to)))
  mIRCd.sraw $1 $mIRCd.reply(004,$mIRCd.info($1,nick))
  mIRCd.raw005 $1
  mIRCd_command_lusers $1
  mIRCd_command_motd $1
  if ($mIRCd(DEFAULT_USERMODES).temp == +) {
    mIRCd.updateUser $1 modes +
    if ($mIRCd(AUTOJOIN_CHANS).temp == $null) { return }
    var %this.skipFlag = 1
  }
  if (%this.skipFlag != 1) {
    var %these.modes = $mIRCd(DEFAULT_USERMODES).temp
    mIRCd.updateUser $1 modes %these.modes
    mIRCd.raw $1 $+(:,$mIRCd.fulladdr($1)) MODE $mIRCd.info($1,nick) $+(:,%these.modes)
    if (x isincs %these.modes) { mIRCd.hostQuit $1 }
    if (i isincs %these.modes) { hadd -m $mIRCd.invisible $1 $ctime }
    if (o isincs %these.modes) { hadd -m $mIRCd.opersOnline $1 $ctime }
    ; `-> I'm only adding this one on the off chance somebody totally ignored my warning and removed o from the forbidden list.
  }
  if ($mIRCd(AUTOJOIN_CHANS).temp != $null) {
    var %these.chans = $v1
    mIRCd.sraw $1 NOTICE $mIRCd.info($1,nick) :*** Notice -- Automatically joining channel(s)...
    $+(.timermIRCd.autojoin,$1) -o 1 5 mIRCd_command_join $1 JOIN %these.chans
  }
}
alias mIRCd.raw005 {
  ; /mIRCd.raw005 <sockname>

  if ($hcount($mIRCd.targMax) > 0) { var %this.targmax = $+(TARGMAX=,$sorttok($left($regsubex($str(.,$hget($mIRCd.targMax,0).item),/./g,$iif(TARGMAX_* iswm $hget($mIRCd.targMax,\n).item && $hget($mIRCd.targMax,\n).data isnum 1-,$+($gettok($hget($mIRCd.targMax,\n).item,2,95),:,$iif($hget($mIRCd.targMax,\n).data != $null,$v1,$null),$comma))),-1),44,a)) }
  ; `-> Prep. TARGMAX=... first. Send it as the last part of RPL_ISUPPORT last too because of the length(?).
  var %this.prefix = (o $+ $iif($mIRCd(HALFOP).temp == 1,h) $+ v)@ $+ $iif($mIRCd(HALFOP).temp == 1,$chr(37)) $+ +
  var %this.list = $+(ACCEPT=,$mIRCd(MAXACCEPT)) $+(AWAYLEN=,$mIRCd(AWAYLEN)) $iif(B isincs $mIRCd.usermodes,BOT=B) CASEMAPPING=ascii $+(CHANNELLEN=,$mIRCd(MAXCHANNELLEN)) $+(CHANMODES=,$mIRCd.chanModesSupport) CHANTYPES=# DEAF=d $+(KEYLEN=,$mIRCd(KEYLEN)) $+(KICKLEN=,$mIRCd(KICKLEN)) $iif($hfind($mIRCd.commands(1),KNOCK).data != $null,KNOCK) $+(MAXBANS=,$mIRCd(MAXBANS)) $+(MAXCHANNELS=,$mIRCd(MAXCHANNELS)) $iif($hfind($mIRCd.commands(1),MAP).data != $null,MAP) $+(MAXLIST=b:,$mIRCd(MAXBANS)) $+(MAXNICKLEN=,$mIRCd(MAXNICKLEN)) $iif($mIRCd(MAXTARGETS) != $null,$+(MAXTARGETS=,$mIRCd(MAXTARGETS))) $+(MODES=,$mIRCd(MODESPL)) NAMESX $+(NETWORK=,$mIRCd(NETWORK_NAME)) $+(NICKLEN=,$mIRCd(MAXNICKLEN)) $+(PREFIX=,%this.prefix) $+(SILENCE=,$mIRCd(MAXSILENCE)) SAFELIST $+(STATUSMSG=,$gettok(%this.prefix,2,41)) $+(TOPICLEN=,$mIRCd(TOPICLEN)) UHNAMES $iif($hfind($mIRCd.commands(1),USERIP).data != $null,USERIP) $+(USERLEN=,$mIRCd.userLen) $+(USERMODES=,$removecs($mIRCd.userModes, h)) $iif($hfind($mIRCd.commands(1),WALLCHOPS).data != $null,WALLCHOPS) $iif($hfind($mIRCd.commands(1),WALLVOICES).data != $null,WALLVOICES) $iif($hfind($mIRCd.commands(1),WHO).data != $null,WHOX) $iif(%this.targmax != $null,$v1)
  ; ¦-> I'm not 100% sure on if my CASEMAPPING=... is ascii or rfc1459. I've opted for ascii for now. (Make an issue on Github @ https://github.com/Jigsy1/mIRCd/issues and let me know if it's wrong.)
  ; `-> Anything else? Reference: https://defs.ircdocs.horse/defs/isupport.html
  var %this.loop = 0, %this.string = $null
  while (%this.loop < $numtok(%this.list,32)) {
    inc %this.loop 1
    var %this.string = %this.string $gettok(%this.list,%this.loop,32)
    if ($numtok(%this.string,32) == 13) {
      ; `-> WARNING!: Limited to 13 items per line. _DO NOT_ change this number!
      mIRCd.sraw $1 $mIRCd.reply(005,$mIRCd.info($1,nick),%this.string)
      var %this.string = $null
    }
  }
  if (%this.string != $null) { mIRCd.sraw $1 $mIRCd.reply(005,$mIRCd.info($1,nick),%this.string) }
}
alias mIRCd.registerUser {
  ; /mIRCd.registerUser <sockname>

  mIRCd.updateUser $1 passPing $base($rand(0,999999999999),10,10,12)
  var %this.command = mIRCd.raw $1 PING $+(:,$mIRCd.info($1,passPing))
  if ($mIRCd(LOOKUP_DELAY) isnum 1-) {
    var %this.delay = $v1
    if (($bool_fmt($mIRCd(DNS_USERS)) == $false) && ($bool_fmt($mIRCd(ACCESS_IDENT_SERVER)) == $false)) { var %this.delay = 1 }
    if ($mIRCd(CONNECTION_PASS) != $null) {
      if (%this.delay < 5) { var %this.delay = 5 }
      ; `-> Give users an ample time to give the password.
    }
    $+(.timermIRCd.ping,$1) -o 1 %this.delay %this.command
    return
  }
  if ($mIRCd(CONNECTION_PASS) != $null) {
    $+(.timermIRCd.ping,$1) -o 1 5 %this.command
    return
  }
  [ %this.command ]
  ; `-> I don't believe the [ evaulation brackets ] are really necessary here, but I'm leaving them in just incase.
}

; Error message(s):

alias mIRCd.badCreds { return Incorrect credentials $parenthesis($1-) }
alias mIRCd.noMore { return No more connections allowed $parenthesis($1-) }

; EOF
