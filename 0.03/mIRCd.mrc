; mIRCd

#mIRCd on
menu menubar {
  &mIRCd
  .&Debug Window:{ window -ek0n $mIRCd.window }
  .-
  .Die:{ mIRCd.die }
  .Rehash:{ mIRCd.rehash }
  .Restart:{ mIRCd.restart }
  .Start:{ mIRCd.start }
}
on *:signal:mIRCd:{
  ; `-> In conjunction with Saturn's sigmirc.exe tool downloadable from: http://xise.nl/

  if ($istok(DIE END STOP TERMINATE,$1,32) == $true) { mIRCd.die }
  if ($1 == REHASH) { mIRCd.rehash }
  if ($istok(REBOOT RESTART,$1,32) == $true) { mIRCd.restart }
  if ($istok(BEGIN BOOT BOOTUP RUN START STARTUP,$1,32) == $true) { mIRCd.start }
}
on *:sockclose:mIRCd.ident.*:{ mIRCd.ident.destruct $sockname }
on *:sockclose:mIRCd.user.*:{ mIRCd.user.disconnect 1 $sockname $mIRCd.socketClosed }
on *:socklisten:mIRCd.*:{
  var %mIRCd.sockNumber = 1, %mIRCd.sockType = mIRCd.user.
  ; `-> Setting %mIRCd.sockNumber to $ctime would probably be a better idea.
  while ($sock($+(%mIRCd.sockType,%mIRCd.sockNumber)) != $null) { inc %mIRCd.sockNumber }
  mIRCd.user.create $+(%mIRCd.sockType,%mIRCd.sockNumber) $sockname
}
on *:sockopen:mIRCd.ident.*:{
  if ($sockerr == 0) { sockwrite -nt $sockname $hget($mIRCd.ident,$sockname) }
}
on *:sockread:mIRCd.ident.*:{
  var %mIRCd.ident.sockRead = $null
  sockread %mIRCd.ident.sockRead
  tokenize 32 %mIRCd.ident.sockRead

  if ($sockerr > 0) { mIRCd.ident.destruct $sockname }
  else {
    tokenize 58 $3-
    if ($3 != $null) { mIRCd.user.update $+(mIRCd.user.,$gettok($sockname,-1,46)) User $3 }
    mIRCd.ident.destruct $sockname
  }
}
on *:sockread:mIRCd.user.*:{
  var %mIRCd.user.sockRead = $null
  sockread %mIRCd.user.sockRead
  tokenize 32 %mIRCd.user.sockRead

  if ($window($mIRCd.window) != $null) { echo -ci2t "Info text" $v1 * $sockname -> $1- }

  if ($sockerr > 0) { mIRCd.user.disconnect 1 $sockname $mIRCd.socketError }
  else {
    if ($bool_fmt($mIRCd.user($sockname,IsRegistered)) == $false) {
      if ($istok($mIRCd.commands(0),$1,44) == $true) { [ [ $+(mIRCd_pre_,$1) ] ] $sockname $1- }
      else { mIRCd.sraw $sockname $mIRCd.reply(451,$mIRCd.nick($sockname),$1) }
    }
    else {
      if ($istok($mIRCd.commands(1),$1,44) == $true) { [ [ $+(mIRCd_command_,$1) ] ] $sockname $1- }
      else { mIRCd.sraw $sockname $mIRCd.reply(421,$mIRCd.nick($sockname),$1) }
    }
  }
}

; IsRegistered = $false
; `-> Not included (at this juncture): PASS

alias -l mIRCd_pre_nick {
  ; /mIRCd_pre_nick <sockname> NICK [:]<nick>

  if ($3 != $null) {
    var %mIRCd.sockNick = $left($iif($left($3,1) == :,$right($3,-1),$3),$mIRCd(MAXNICKLEN))
    ; `-> Truncate the nick to the maximum length allowed.
    if ($is_valid(%mIRCd.sockNick).nick == $true) {
      if ($is_inUse(%mIRCd.sockNick).nick == $false) {
        if ($is_illegal(%mIRCd.sockNick).nick == $false) {
          mIRCd.map.nick $1 %mIRCd.sockNick
          if ($mIRCd.user($1,RealName) != $null) { mIRCd.register $1 }
        }
        else { mIRCd.sraw $1 $mIRCd.reply(433,$mIRCd.nick($1),%mIRCd.sockNick) }
      }
      else { mIRCd.sraw $1 $mIRCd.reply(433,$mIRCd.nick($1),%mIRCd.sockNick) }
    }
    else { mIRCd.sraw $1 $mIRCd.reply(432,$mIRCd.nick($1),%mIRCd.sockNick) }
  }
  else { mIRCd.sraw $1 $mIRCd.reply(431,$mIRCd.nick($1)) }
}
alias -l mIRCd_pre_pong {
  ; /mIRCd_pre_pong <sockname> PONG <args>

  if ($3 != $null) {
    if ($3 === $+(:,$mIRCd.user($1,PassPing))) {
      hdel $mIRCd.pre $1
      mIRCd.user.update $1 IsRegistered 1
      ; `-> The user is now registered with the IRCd.

      mIRCd.snotice 16384 Client connecting: $mIRCd.nick($1) $parenthesis($gettok($mIRCd.fulladdr($1),2-,33)) $bracket($sock($1).ip)

      mIRCd.sraw $1 $mIRCd.reply(001,$mIRCd.nick($1),$mIRCd.fulladdr($1))
      mIRCd.sraw $1 $mIRCd.reply(002,$mIRCd.nick($1))
      mIRCd.sraw $1 $mIRCd.reply(003,$mIRCd.nick($1),$calc($ctime - $iif($mIRCd(START_TS) != $null,$calc($ctime - $v1),$sock($mIRCd.user($1,ThruSock)).to)))
      mIRCd.sraw $1 $mIRCd.reply(004,$mIRCd.nick($1))

      mIRCd.005 $1

      mIRCd_command_lusers $1
      mIRCd_command_motd $1
    }
    else {
      if ($mIRCd.user($1,PassPing) != $null) { mIRCd.sraw $1 $mIRCd.reply(513,$mIRCd.nick($1),$mIRCd.user($1,PassPing)) }
    }
  }
  else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
}
alias -l mIRCd_pre_quit {
  ; /mIRCd_pre_quit <sockname>

  mIRCd.user.disconnect 0 $1
}
alias -l mIRCd_pre_user {
  ; /mIRCd_pre_user <sockname> USER <ident> <?> <?> :<real name>

  if ($mIRCd.user($1,RealName) == $null) {
    if ($3 != $null) {
      mIRCd.user.update $1 User $+(~,$left($legalizeIdent($3),9))
      if ($right($6-,-1) != $null) {
        mIRCd.user.update $1 RealName $left($v1,50)
        if ($mIRCd.user($1,Nick) != $null) { mIRCd.register $1 }
      }
      else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
    }
    else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
  }
  else { mIRCd.sraw $1 $mIRCd.reply(462,$mIRCd.nick($1)) }
}

; IsRegistered = $true

alias -l mIRCd_command_admin {
  ; /mIRCd_command_admin <sockname> ADMIN

  if ($mIRCd(ADMIN_LINE1) != $null) {
    ; `-> Require at least ADMIN_LINE1. ADMIN_LINE2 and ADMIN_LINE3 are optional.
    mIRCd.sraw $1 $mIRCd.reply(256 $mIRCd.nick($1))
    mIRCd.sraw $1 $mIRCd.reply(257,$mIRCd.nick($1),$v1)
    if ($mIRCd(ADMIN_LINE2) != $null) { mIRCd.sraw $1 $mIRCd.reply(258,$mIRCd.nick($1),$v1) }
    if ($mIRCd(ADMIN_LINE3) != $null) { mIRCd.sraw $1 $mIRCd.reply(259,$mIRCd.nick($1),$v1) }
  }
  else { mIRCd.sraw $1 $mIRCd.reply(423,$mIRCd.nick($1)) }
}

alias -l mIRCd_command_away {
  ; /mIRCd_command_away <sockname> AWAY :[away message]

  if ($3- != $null) {
    if ($3- == :) {
      if ($mIRCd.user($1,Away) != $null) { mIRCd.user.unset $1 Away }
      mIRCd.sraw $1 $mIRCd.reply(305,$mIRCd.nick($1))
    }
    else {
      mIRCd.user.update $1 Away $left($iif($left($3-,1) == :,$right($3-,-1),$3-),$mIRCd(AWAYLEN))
      mIRCd.sraw $1 $mIRCd.reply(306,$mIRCd.nick($1))
    }
  }
  else {
    if ($mIRCd.user($1,Away) != $null) { mIRCd.user.unset $1 Away }
    mIRCd.sraw $1 $mIRCd.reply(305,$mIRCd.nick($1))
  }
}

alias -l mIRCd_command_clearmode {
  ; /mIRCd_command_clearmode <sockname> CLEARMODE <#chan> [<modes>]

  if ($has_modeSet($1,o).user == $true) {
    if ($3 != $null) {
      if ($is_inUse($3).chan == $true) {
        mIRCd.snotice 256 HACK(4): $mIRCd.nick($1) $upper($2) $3 $4
        var %mIRCd.clearChan = $getChanID($3)
        var %mIRCd.clearModes = $iif($4 != $null,$v1,$gettok($mIRCd.modes(chan),1,32))
        var %mIRCd.clearNumber = 0
        var %mIRCd.clearMinus = -
        var %mIRCd.clearArgMinus = $null
        while (%mIRCd.clearNumber < $len(%mIRCd.clearModes)) {
          inc %mIRCd.clearNumber
          var %mIRCd.clearChar = $mid(%mIRCd.clearModes,%mIRCd.clearNumber,1)

          if (%mIRCd.clearChar === b) { }
          if (%mIRCd.clearChar === k) {
            if ($has_modeSet(%mIRCd.clearChan,%mIRCd.clearChar).chan == $true) {
              mIRCd.chan.update %mIRCd.clearChan Modes $removecs($mIRCd.chan(%mIRCd.clearChan,Modes),%mIRCd.clearChar)
              var %mIRCd.clearMinus = $+(%mIRCd.clearMinus,%mIRCd.clearChar)
              var %mIRCd.clearArgMinus = %mIRCd.clearArgMinus $mIRCd.chan(%mIRCd.clearChan,Key)
              mIRCd.chan.unset %mIRCd.clearChan Key
            }
          }
          if ($poscs(hov,%mIRCd.clearChar) != $null) {
            var %mIRCd.userNumber = 0
            while (%mIRCd.userNumber < $hcount($mIRCd.chanusers(%mIRCd.clearChan))) {
              inc %mIRCd.userNumber
              var %mIRCd.clearSock = $hget($mIRCd.chanusers(%mIRCd.clearChan),%mIRCd.userNumber).item
              if ($has_chanStatus(%mIRCd.clearChan,%mIRCd.clearSock,%mIRCd.clearChar) == $true) {
                mIRCd.chan.user.update %mIRCd.clearChan %mIRCd.clearSock 0 $calc($poscs(ohv,%mIRCd.clearChar) + 2)
                var %mIRCd.clearMinus = $+(%mIRCd.clearMinus,%mIRCd.clearChar)
                var %mIRCd.clearArgMinus = %mIRCd.clearArgMinus $mIRCd.nick(%mIRCd.clearSock)
              }
            }
          }
          if ($poscs(ilmnpstuCNOPS,%mIRCd.clearChar) != $null) {
            if ($has_modeSet(%mIRCd.clearChan,%mIRCd.clearChar).chan == $true) {
              mIRCd.chan.update %mIRCd.clearChan Modes $removecs($mIRCd.chan(%mIRCd.clearChan,Modes),%mIRCd.clearChar)
              var %mIRCd.clearMinus = $+(%mIRCd.clearMinus,%mIRCd.clearChar)
              if (%mIRCd.clearChar === l) { mIRCd.chan.unset %mIRCd.clearChan Limit }
            }
          }
          if ($calc($len(%mIRCd.clearMinus) - 1) >= $mIRCd(MODESPL)) {
            var %mIRCd.userNumber = 0
            while (%mIRCd.userNumber < $hcount($mIRCd.chanusers(%mIRCd.clearChan))) {
              inc %mIRCd.userNumber
              mIRCd.sraw $hget($mIRCd.chanusers(%mIRCd.clearChan),%mIRCd.userNumber).item MODE $3 %mIRCd.clearMinus %mIRCd.clearArgMinus
            }
            var %mIRCd.clearMinus = -
            var %mIRCd.clearArgMinus = $null
          }
        }
        if ($len(%mIRCd.clearMinus) > 1) {
          var %mIRCd.userNumber = 0
          while (%mIRCd.userNumber < $hcount($mIRCd.chanusers(%mIRCd.clearChan))) {
            inc %mIRCd.userNumber
            mIRCd.sraw $hget($mIRCd.chanusers(%mIRCd.clearChan),%mIRCd.userNumber).item MODE $3 %mIRCd.clearMinus %mIRCd.clearArgMinus
          }
        }
      }
      else { }
    }
    else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
  }
  else { mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.nick($1)) }
}

alias -l mIRCd_command_die {
  ; /mIRCd_command_die <sockname> DIE [<password>]

  if ($has_modeSet($1,o).user == $true) {
    if ($bool_fmt($mIRCd(DIE_REQUIRE_PASSWORD)) == $true) {
      if ($mIRCd.mkpasswd($3) === $mIRCd(DIE_PASSWORD)) { mIRCd.die $mIRCd.fulladdr($1) }
      else { }
    }
    else { mIRCd.die $mIRCd.fulladdr($1) }
  }
  else { }
}

alias -l mIRCd_command_hash {
  ; /mIRCd_command_hash <sockname>

  mIRCd.sraw $1 NOTICE $mIRCd.nick($1) :Hash Table Statistics:
  mIRCd.sraw $1 NOTICE $mIRCd.nick($1) :Channel entries: $hcount($mIRCd.chans)
  mIRCd.sraw $1 NOTICE $mIRCd.nick($1) :Client entries: $hcount($mIRCd.users)
}

alias -l mIRCd_command_help {
  ; /mIRCd_command_help <sockname> HELP [command]

  if ($3 != $null) {
    if ($isfile($mIRCd.file.help($v1)) == $true) {
      ; ,-> For this, I've decided to use * instead of $3 because I've always felt that the way it's actually set out on other IRCds is so unsightly. E.g. [01:13:39] index End of /HELP
      mIRCd.sraw $1 $mIRCd.reply(704,$mIRCd.nick($1),*,Help for $upper($3))
      mIRCd.sraw $1 $mIRCd.reply(705,$mIRCd.nick($1),*,$+(---------,$str(-,$len($3))))
      var %mIRCd.lineNumber = 0
      while (%mIRCd.lineNumber < $lines($mIRCd.file.help($3))) {
        inc %mIRCd.lineNumber
        mIRCd.sraw $1 $mIRCd.reply(705,$mIRCd.nick($1),*,$replacecs($read($mIRCd.file.help($3), n, %mIRCd.lineNumber), <helpCommand>, $upper($2), <nick>, $mIRCd.nick($1), <thisCommand>, $upper($3)))
      }
      mIRCd.sraw $1 $mIRCd.reply(705,$mIRCd.nick($1),*)
      mIRCd.sraw $1 $mIRCd.reply(706,$mIRCd.nick($1),*)
    }
    else { mIRCd.sraw $1 NOTICE $mIRCd.nick($1) :*** No help available for $+($upper($3),.) }
  }
  else {
    var %mIRCd.helpNumber = 0
    while (%mIRCd.helpNumber < $numtok($mIRCd.commands(1),44)) {
      inc %mIRCd.helpNumber
      mIRCd.sraw $1 NOTICE $+(:,$gettok($mIRCd.commands(1),%mIRCd.helpNumber,44))
    }
  }
}

alias -l mIRCd_command_invite {
  ; /mIRCd_command_invite <sockname> INVITE [<nick> <#chan>]

  if ($3 != $null) {
    if ($is_inUse($3).nick == $true) {
      var %mIRCd.inviteSock = $getSockname($3)
      if ($is_inUse($4).chan == $true) {
        var %mIRCd.inviteChan = $getChanID($4)
        if ($is_onChan(%mIRCd.inviteChan,$1) == $true) {
          if ($is_onChan(%mIRCd.inviteChan,%mIRCd.inviteSock) == $false) {
            if ($is_invitePending(%mIRCd.inviteChan,%mIRCd.inviteSock) == $false) { mIRCd.user.update %mIRCd.inviteSock Invites $+($mIRCd.user(%mIRCd.inviteSock,Invites),$comma,$gettok(%mIRCd.inviteChan,-1,46)) }
            ; `-> We only want to cache the invite once.
            mIRCd.sraw $1 $mIRCd.reply(341,$mIRCd.nick($1),$3,$4)
            mIRCd.raw %mIRCd.inviteSock $+(:,$mIRCd.fulladdr($1)) INVITE $3 $4
          }
          else { mIRCd.sraw $1 $mIRCd.reply(443,$mIRCd.nick($1),$3,$4) }
        }
        else { mIRCd.sraw $1 $mIRCd.reply(442,$mIRCd.nick($1),$4) }
      }
      else { mIRCd.sraw $1 $mIRCd.reply(442,$mIRCd.nick($1),$4) }
    }
    else { mIRCd.sraw $1 $mIRCd.reply(401,$mIRCd.nick($1),$3) }
  }
  else {
    var %mIRCd.inviteNumber = 0
    while (%mIRCd.inviteNumber < $numtok($mIRCd.user($1,Invites),44)) {
      inc %mIRCd.inviteNumber
      var %mIRCd.inviteName = $+(mIRCd.chan.,$gettok($mIRCd.user($1,Invites),%mIRCd.inviteNumber,44))
      mIRCd.sraw $1 $mIRCd.reply(346,$mIRCd.nick($1),$mIRCd.chan(%mIRCd.inviteName,Name))
    }
    mIRCd.sraw $1 $mIRCd.reply(347,$mIRCd.nick($1))
  }
}

alias -l mIRCd_command_ison {
  ; /mIRCd_command_ison <sockname> ISON <nick [nick nick ...]>

  if ($3- != $null) {
    var %mIRCd.isonNumber = 0
    while (%mIRCd.isonNumber < $numtok($3-,32)) {
      inc %mIRCd.isonNumber
      var %mIRCd.isonName = $gettok($3-,%mIRCd.isonNumber,32)
      if ($is_inUse(%mIRCd.isonName).nick == $true) {
        var %mIRCd.isonString = %mIRCd.isonString $mIRCd.nick($getSockname(%mIRCd.isonName))
        ; `-> The ISON string must return the nick as is. E.g. If their nick is HaNNaH, it can't return hannah, hAnnAh, hannaH, etc. It *has* to be HaNNaH.
      }
    }
    mIRCd.sraw $1 $mIRCd.reply(303,$mIRCd.nick($1),%mIRCd.isonString)
  }
  else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
}

alias -l mIRCd_command_join {
  ; /mIRCd_command_join <sockname> JOIN <#chan[,#chan,#chan,...]> [<key[,key,key,...]>]

  if ($3 != $null) {
    var %mIRCd.joinNumber = 0
    var %mIRCd.joinArgNumber = 0
    while (%mIRCd.joinNumber < $numtok($3,44)) {
      inc %mIRCd.joinNumber
      var %mIRCd.joinName = $left($gettok($3,%mIRCd.joinNumber,44),$mIRCd(CHANNELLEN))
      if ($numtok($mIRCd.user($1,Chans),44) <= $mIRCd(MAXCHANNELS)) {
        if ($is_valid(%mIRCd.joinName).chan == $true) {
          if ($is_inUse(%mIRCd.joinName).chan == $false) {
            if ($is_illegal(%mIRCd.joinName).chan == $false) { mIRCd.chan.create %mIRCd.joinName $1 }
            else {
              mIRCd.sraw $1 $mIRCd.reply(474,$mIRCd.nick($1),%mIRCd.joinName)
              mIRCd.dwallops $+($mIRCd.nick($1),$bracket($gettok($mIRCd.fulladdr($1),2-,33))) attempted to join an illegal channel: %mIRCd.joinName
            }
          }
          else {
            var %mIRCd.joinChan = $getChanID(%mIRCd.joinName)
            if ($is_onChan(%mIRCd.joinChan,$1) == $false) {
              ; `-> We need this otherwise the server would keep classifying them as joining the channel.

              /*
              ; +b
              if ($is_bannedFrom(%mIRCd.joinChan,$1) == $true) { mIRCd.sraw $1 $mIRCd.reply(474,$mIRCd.nick($1),%mIRCd.joinName) }
              */

              if ($has_modeSet(%mIRCd.joinChan,i).chan == $true) {
                if ($is_invitePending(%mIRCd.joinChan,$1) == $true) {
                  mIRCd.chan.user.add %mIRCd.joinChan $1
                  mIRCd.user.update $1 Invites $remtok($mIRCd.user($1,Invites),$gettok(%mIRCd.joinChan,-1,46),1,44)
                }
                else { mIRCd.sraw $1 $mIRCd.reply(473,$mIRCd.nick($1),%mIRCd.joinName) }
              }
              elseif ($has_modeSet(%mIRCd.joinChan,k).chan == $true) {
                inc %mIRCd.joinArgNumber
                var %mIRCd.joinArgToken = $gettok($4-,%mIRCd.joinArgNumber,44)
                if (%mIRCd.joinArgToken != $null) {
                  if (%mIRCd.joinArgToken === $mIRCd.chan(%mIRCd.joinChan,Key)) { mIRCd.chan.user.add %mIRCd.joinChan $1 }
                  else { mIRCd.sraw $1 $mIRCd.reply(475,$mIRCd.nick($1),%mIRCd.joinName) }
                }
                else { mIRCd.sraw $1 $mIRCd.reply(475,$mIRCd.nick($1),%mIRCd.joinName) }
              }
              elseif ($has_modeSet(%mIRCd.joinChan,l).chan == $true) {
                if ($hcount($mIRCd.chanusers(%mIRCd.joinChan)) < $mIRCd.chan(%mIRCd.joinChan,Limit)) { mIRCd.chan.user.add %mIRCd.joinChan $1 }
                else { mIRCd.sraw $1 $mIRCd.reply(471,$mIRCd.nick($1),%mIRCd.joinName) }
              }
              elseif ($has_modeSet(%mIRCd.joinChan,O).chan == $true) {
                ; `-> Need to be an IRC operator in order to join.
                if ($has_modeSet($1,O).user == $true) { mIRCd.chan.user.add %mIRCd.joinChan $1 }
                else { mIRCd.sraw $1 $mIRCd.reply(470,$mIRCd.nick($1),%mIRCd.joinName) }
              }
              else { mIRCd.chan.user.add %mIRCd.joinChan $1 }
            }
          }
        }
        else { }
      }
      else { mIRCd.sraw $1 $mIRCd.reply(405,$mIRCd.nick($1),%mIRCd.joinName) }
    }
  }
  else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
}

alias -l mIRCd_command_kick {
  ; /mIRCd_command_kick <sockname> KICK <#chan> <nick> <reason>

  if ($3 != $null) {
    if ($is_inUse($3).chan == $true) {
      var %mIRCd.kickChan = $getChanID($3)
      if ($is_onChan(%mIRCd.kickChan,$1) == $true) {
        if ($4 != $null) {
          if ($is_inUse($4).nick == $true) {
            var %mIRCd.kickSock = $getSockname($4)
            if ($is_onChan(%mIRCd.kickChan,%mIRCd.kickSock) == $true) {
              if (($has_ChanStatus(%mIRCd.kickChan,$1,o) == $true) || ($has_chanStatus(%mIRCd.kickChan,$1,h) == $true)) {
                if ($has_modeSet(%mIRCd.kickSock,k).user == $false) {
                  var %mIRCd.userNumber = 0
                  while (%mIRCd.userNumber < $hcount($mIRCd.chanusers(%mIRCd.kickChan))) {
                    inc %mIRCd.userNumber
                    mIRCd.raw $hget($mIRCd.chanusers(%mIRCd.kickChan),%mIRCd.userNumber).item $+(:,$mIRCd.fulladdr($1)) KICK $3 $4 $colonize($iif($5-,$left($v1,$mIRCd(KICKLEN)),$4))
                  }
                  mIRCd.chan.user.del %mIRCd.kickChan %mIRCd.kickSock
                }
                else { mIRCd.sraw $1 $mIRCd.reply(484,$mIRCd.nick($1),$3,$4) }
              }
              else { mIRCd.sraw $1 $mIRCd.reply(482,$mIRCd.nick($1),$3) }
            }
            else { }
          }
          else { }
        }
        else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
      }
      else { }
    }
    else { }
  }
  else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
}

alias -l mIRCd_command_kill {
  ; /mIRCd_command_kill <sockname> KILL <nick> <reason>

  if ($has_modeSet($1,o).user == $true) {
    if ($3 != $null) {
      if ($is_inUse($3).nick == $true) {
        var %mIRCd.killSock = $getSockname($3)
        if ($4- != $null) {
          if ($has_modeSet(%mIRCd.killSock,k).user == $false) {

            mIRCd.user.disconnect 2 %mIRCd.killSock $mIRCd.nick($1) $parenthesis($decolonize($4-))

          }
          else { }
        }
        else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
      }
      else { }
    }
    else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
  }
  else { mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.nick($1)) }
}

alias -l mIRCd_command_list {
  ; /mIRCd_command_list <sockname> LIST [...]

  var %mIRCd.listNumber = 0
  while (%mIRCd.listNumber < $hcount($mIRCd.chans)) {
    inc %mIRCd.listNumber
    var %mIRCd.listChan = $hget($mIRCd.chans,%mIRCd.listNumber).item

    var %mIRCd.listFlag = 1
    if ($is_hiddenChan(%mIRCd.listChan) == $true) {
      if ($is_onChan(%mIRCd.listChan,$1) == $false) { var %mIRCd.listFlag = 0 }
    }

    if (%mIRCd.listFlag == 1) {
      var %mIRCd.listModes = $+(+,$mIRCd.chan(%mIRCd.listChan,Modes))

      mIRCd.sraw $1 322 $mIRCd.nick($1) $mIRCd.chan(%mIRCd.listChan,Name) $hcount($mIRCd.chanusers(%mIRCd.listChan)) $+(:,$bracket(%mIRCd.listModes)) $mIRCd.chan(%mIRCd.listChan,Topic)
      ; `-> [+ntlk 67 *], though * actually shows the key if you're on the channel.
    }
  }
  mIRCd.sraw $1 $mIRCd.reply(323,$mIRCd.nick($1))
}

alias -l mIRCd_command_lusers {
  ; /mIRCd_command_lusers <sockname>

  mIRCd.sraw $1 $mIRCd.reply(251,$mIRCd.nick($1))
  mIRCd.sraw $1 $mIRCd.reply(252,$mIRCd.nick($1))
  if ($hcount($mIRCd.pre) > 0) { mIRCd.sraw $1 $mIRCd.reply(253,$mIRCd.nick($1)) }
  mIRCd.sraw $1 $mIRCd.reply(254,$mIRCd.nick($1))
  mIRCd.sraw $1 $mIRCd.reply(255,$mIRCd.nick($1))
  ; LOCAL_INFO/MAX_INFO
  ; GLOBAL_INFO/MAX_INFO
}

alias -l mIRCd_command_mkpasswd {
  ; /mIRCd_command_mkpasswd <sockname> MKPASSWD <text>

  if ($3 != $null) { mIRCd.sraw $1 NOTICE $mIRCd.nick($1) :*** $+($upper($2),:) $mIRCd.mkpasswd($v1) }
  else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
}

alias -l mIRCd_command_mode {
  ; /mIRCd_command_mode <sockname> MODE <target> [<modestring> [<args>]]

  if ($3 != $null) {
    if ($is_valid($3).chan == $true) {
      if ($is_inUse($3).chan == $true) {
        var %mIRCd.modeChan = $getChanID($3)
        if ($4 != $null) {
          if ($istok(b +b,$4,32) == $true) {
            ; `-> +b seems to work regardless of +p/+s/the user is not on it.

            mIRCd.sraw $1 $mIRCd.reply(368,$mIRCd.nick($1),$3)

          }
          else {
            if ($is_onChan(%mIRCd.modeChan,$1) == $true) {
              if (($has_chanStatus(%mIRCd.modeChan,$1,o) == $true) || ($has_chanStatus(%mIRCd.modeChan,$1,h) == $true) || ($bool_fmt(%mIRCd.chanStatus) == $true)) {
                ; `-> Need to fix this so only +h can use -/+bv only. (Maybe +lmCNS?)

                var %mIRCd.chanStatus = 1
                ; `-> Just incase they -o themselves during the process of setting modes.

                ; var %mIRCd.modePre = $mIRCd.chan(%mIRCd.modeChan,Modes)
                ; `-> Necessity pending...

                var %mIRCd.modeFlag = $null
                var %mIRCd.modeMinus = -
                var %mIRCd.modePlus = +
                var %mIRCd.modeNumber = 0

                var %mIRCd.modeArgNumber = 0
                var %mIRCd.modeArgMinus = $null
                var %mIRCd.modeArgPlus = $null

                while (%mIRCd.modeNumber < $len($4)) {
                  inc %mIRCd.modeNumber
                  var %mIRCd.modeChar = $mid($4,%mIRCd.modeNumber,1)
                  if (%mIRCd.modeFlag == $null) {
                    if ($pos(-+,%mIRCd.modeChar) != $null) { var %mIRCd.modeFlag = %mIRCd.modeChar }
                  }
                  else {
                    if ($pos(-+,%mIRCd.modeChar) != $null) { var %mIRCd.modeFlag = %mIRCd.modeChar }
                    else {
                      if (%mIRCd.modeFlag == -) {
                        if ($poscs(OP,%mIRCd.modeChar) != $null) {
                          if ($has_modeSet($1,o).user == $true) {
                            if ($has_modeSet(%mIRCd.modeChan,%mIRCd.modeChar).chan == $true) {
                              mIRCd.chan.update %mIRCd.modeChan Modes $removecs($mIRCd.chan(%mIRCd.modeChan,Modes),%mIRCd.modeChar)
                              var %mIRCd.modeMinus = $+(%mIRCd.modeMinus,%mIRCd.modeChar)
                              if (%mIRCd.modeChar isincs %mIRCd.modePlus) { var %mIRCd.modePlus = $removecs(%mIRCd.modePlus,%mIRCd.modeChar) }
                            }
                          }
                          else { mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.nick($1)) }
                        }

                        ; elseif (%mIRCd.modeChar === b) { }

                        elseif (%mIRCd.modeChar === k) {
                          inc %mIRCd.modeArgNumber
                          var %mIRCd.modeArgToken = $gettok($5-,%mIRCd.modeArgNumber,32)
                          if (%mIRCd.modeArgToken != $null) {
                            if ($has_modeSet(%mIRCd.modeChan,%mIRCd.modeChar).chan == $true) {
                              if (%mIRCd.modeArgToken === $mIRCd.chan(%mIRCd.modeChan,Key)) {
                                var %mIRCd.modeLastKey = $+(%mIRCd.modeChar,:,$v2)
                                mIRCd.chan.update %mIRCd.modeChan Modes $removecs($mIRCd.chan(%mIRCd.modeChan,Modes),%mIRCd.modeChar)
                                var %mIRCd.modeMinus = $+(%mIRCd.modeMinus,%mIRCd.modeChar)
                                var %mIRCd.modeArgMinusToken = $+(%mIRCd.modeChar,:,%mIRCd.modeArgToken)
                                var %mIRCd.modeArgMinus = %mIRCd.modeArgMinus %mIRCd.modeArgMinusToken
                                if (%mIRCd.modeChar isincs %mIRCd.modePlus) {
                                  var %mIRCd.modePlus = $removecs(%mIRCd.modePlus,%mIRCd.modeChar)
                                  var %mIRCd.modeArgPlus = $remtokcs(%mIRCd.modeArgPlus,%mIRCd.modeArgMinusToken,1,32)
                                }
                                mIRCd.chan.unset %mIRCd.modeChan Key
                              }
                              else { mIRCd.sraw $1 $mIRCd.reply(467,$mIRCd.nick($1),$3) }
                            }
                          }
                          else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2,$+(%mIRCd.modeFlag,%mIRCd.modeChar)) }
                        }

                        elseif ($poscs(hov,%mIRCd.modeChar) != $null) {
                          inc %mIRCd.modeArgNumber
                          var %mIRCd.modeArgToken = $gettok($5-,%mIRCd.modeArgNumber,32)
                          if (%mIRCd.modeArgToken != $null) {
                            if ($getSockname(%mIRCd.modeArgToken) != $null) {
                              var %mIRCd.modeSock = $v1
                              if ($is_onChan(%mIRCd.modeChan,%mIRCd.modeSock) == $true) {
                                if ($has_chanStatus(%mIRCd.modeChan,%mIRCd.modeSock,%mIRCd.modeChar) == $true) {
                                  if ((%mIRCd.modeChar === o) && ($has_modeSet(%mIRCd.modeSock,k).user == $true)) {
                                    mIRCd.sraw $1 $mIRCd.reply(484,$mIRCd.nick($1),$3,%mIRCd.modeArgToken)
                                    ; `-> 485 in the case of a service like ChanServ?
                                  }
                                  else {
                                    mIRCd.chan.user.update %mIRCd.modeChan %mIRCd.modeSock 0 $calc($poscs(ohv,%mIRCd.modeChar) + 2)
                                    var %mIRCd.modeMinus = $+(%mIRCd.modeMinus,%mIRCd.modeChar)
                                    var %mIRCd.modeArgMinusToken = $+(%mIRCd.modeChar,:,%mIRCd.modeArgToken)
                                    var %mIRCd.modeArgMinus = %mIRCd.modeArgMinus %mIRCd.modeArgMinusToken
                                    if ($istokcs(%mIRCd.modeArgPlus,%mIRCd.modeArgMinusToken,32) == $true) {
                                      var %mIRCd.modeArgPlus = $remtokcs(%mIRCd.modeArgPlus,%mIRCd.modeArgMinusToken,1,32)
                                      var %mIRCd.modePlus = $remove($remtok($regsubex(%mIRCd.modePlus,/(.)/g,$+(\t,.)),%mIRCd.modeChar,1,46), .)
                                    }
                                    ; `-> Hopefully this won't cause any issues. E.g. +ohv Jigsy Jigsy Jigsy, +vvv Jigsy Jigsy Jigsy, +v-v+v-v+h Jigsy Jigsy Jigsy Jigsy Jigsy, +ohvvvv Jigsy, etc.
                                  }
                                }
                              }
                            }
                          }
                        }

                        elseif (%mIRCd.modeChar === l) {
                          if ($has_modeSet(%mIRCd.modeChan,%mIRCd.modeChar).chan == $true) {
                            mIRCd.chan.update %mIRCd.modeChan Modes $removecs($mIRCd.chan(%mIRCd.modeChan,Modes),%mIRCd.modeChar)
                            var %mIRCd.modeMinus = $+(%mIRCd.modeMinus,%mIRCd.modeChar)
                            if (%mIRCd.modeChar isincs %mIRCd.modePlus) {
                              var %mIRCd.modePlus = $removecs(%mIRCd.modePlus,%mIRCd.modeChar)
                              var %mIRCd.modeArgPlus = $remtokcs(%mIRCd.modeArgPlus,$+(%mIRCd.modeChar:,$mIRCd.chan(%mIRCd.modeChan,Limit)),1,32)
                            }
                            mIRCd.chan.unset %mIRCd.modeChan Limit
                          }
                        }

                        elseif ($poscs(imnpstuCNS,%mIRCd.modeChar) != $null) {
                          if ($has_modeSet(%mIRCd.modeChan,%mIRCd.modeChar).chan == $true) {
                            mIRCd.chan.update %mIRCd.modeChan Modes $removecs($mIRCd.chan(%mIRCd.modeChan,Modes),%mIRCd.modeChar)
                            var %mIRCd.modeMinus = $+(%mIRCd.modeMinus,%mIRCd.modeChar)
                            if (%mIRCd.modeChar isincs %mIRCd.modePlus) { var %mIRCd.modePlus = $removecs(%mIRCd.modePlus,%mIRCd.modeChar) }
                          }
                        }
                        else { mIRCd.sraw $1 $mIRCd.reply(501,$mIRCd.nick($1),%mIRCd.modeChar) }
                      }
                      else {
                        if ($poscs(OP,%mIRCd.modeChar) != $null) {
                          if ($has_modeSet($1,o).user == $true) {
                            if ($has_modeSet(%mIRCd.modeChan,%mIRCd.modeChar).chan == $false) {
                              mIRCd.chan.update %mIRCd.modeChan Modes $+($mIRCd.chan(%mIRCd.modeChan,Modes),%mIRCd.modeChar)
                              var %mIRCd.modePlus = $+(%mIRCd.modePlus,%mIRCd.modeChar)
                              if (%mIRCd.modeChar isincs %mIRCd.modeMinus) { var %mIRCd.modeMinus = $removecs(%mIRCd.modeMinus,%mIRCd.modeChar) }
                            }
                          }
                          else { mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.nick($1)) }
                        }

                        ; elseif (%mIRCd.modeChar === b) { }

                        elseif ($poscs(hov,%mIRCd.modeChar) != $null) {
                          inc %mIRCd.modeArgNumber
                          var %mIRCd.modeArgToken = $gettok($5-,%mIRCd.modeArgNumber,32)
                          if (%mIRCd.modeArgToken != $null) {
                            if ($getSockname(%mIRCd.modeArgToken) != $null) {
                              var %mIRCd.modeSock = $v1
                              if ($is_onChan(%mIRCd.modeChan,%mIRCd.modeSock) == $true) {
                                if ($has_chanStatus(%mIRCd.modeChan,%mIRCd.modeSock,%mIRCd.modeChar) == $false) {
                                  mIRCd.chan.user.update %mIRCd.modeChan %mIRCd.modeSock 1 $calc($poscs(ohv,%mIRCd.modeChar) + 2)
                                  var %mIRCd.modePlus = $+(%mIRCd.modePlus,%mIRCd.modeChar)
                                  var %mIRCd.modeArgPlusToken = $+(%mIRCd.modeChar,:,%mIRCd.modeArgToken)
                                  var %mIRCd.modeArgPlus = %mIRCd.modeArgPlus %mIRCd.modeArgPlusToken
                                  if ($istokcs(%mIRCd.modeArgMinus,%mIRCd.modeArgPlusToken,32) == $true) {
                                    var %mIRCd.modeArgMinus = $remtokcs(%mIRCd.modeArgMinus,%mIRCd.modeArgPlusToken,1,32)
                                    var %mIRCd.modeMinus = $remove($remtok($regsubex(%mIRCd.modeMinus,/(.)/g,$+(\t,.)),%mIRCd.modeChar,1,46), .)
                                  }
                                  ; `-> Ditto.
                                }
                              }
                            }
                          }
                          ; Doesn't tell you insufficient parameters unlike +k and +l.
                        }

                        elseif (%mIRCd.modechar === k) {
                          inc %mIRCd.modeArgNumber
                          var %mIRCd.modeArgToken = $gettok($5-,%mIRCd.modeArgNumber,32)
                          if (%mIRCd.modeArgToken != $null) {
                            if ($is_valid(%mIRCd.modeArgToken).key == $true) {
                              if ($has_modeSet(%mIRCd.modeChan,%mIRCd.modeChar).chan == $false) {
                                mIRCd.chan.update %mIRCd.modeChan Modes $+($mIRCd.chan(%mIRCd.modeChan,Modes),%mIRCd.modeChar)
                                var %mIRCd.modePlus = $+(%mIRCd.modePlus,%mIRCd.modeChar)
                                var %mIRCd.modeArgPlusToken = $+(%mIRCd.modeChar,:,%mIRCd.modeArgToken)
                                var %mIRCd.modeArgPlus = %mIRCd.modeArgPlus %mIRCd.modeArgPlusToken
                                if (%mIRCd.modeChar isincs %mIRCd.modeMinus) {
                                  var %mIRCd.modeMinus = $removecs(%mIRCd.modeMinus,%mIRCd.modeChar)
                                  var %mIRCd.modeArgMinus = $remtokcs(%mIRCd.modeArgMinus,%mIRCd.modeLastKey,1,32)
                                }
                                mIRCd.chan.update %mIRCd.modeChan Key %mIRCd.modeArgToken
                              }
                              else { mIRCd.sraw $1 $mIRCd.reply(467,$mIRCd.nick($1),$3) }
                            }
                            else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2,$+(%mIRCd.modeFlag,%mIRCd.modeChar)) }
                          }
                          else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2,$+(%mIRCd.modeFlag,%mIRCd.modeChar)) }
                        }

                        elseif (%mIRCd.modechar === l) {
                          ; `-> Don't include the parameter in the ArgMinus string if removing it.
                          inc %mIRCd.modeArgNumber
                          var %mIRCd.modeArgToken = $gettok($5-,%mIRCd.modeArgNumber,32)
                          if (%mIRCd.modeArgToken != $null) {
                            if (%mIRCd.modeArgToken isnum 1-) {
                              if ($has_modeSet(%mIRCd.modeChan,%mIRCd.modeChar).chan == $false) {
                                mIRCd.chan.update %mIRCd.modeChan Modes $+($mIRCd.chan(%mIRCd.modeChan,Modes),%mIRCd.modeChar)
                                var %mIRCd.modePlus = $+(%mIRCd.modePlus,%mIRCd.modeChar)
                                var %mIRCd.modeArgPlusToken = $+(%mIRCd.modeChar,:,%mIRCd.modeArgToken)
                                var %mIRCd.modeArgPlus = %mIRCd.modeArgPlus %mIRCd.modeArgPlusToken
                                if (%mIRCd.modeChar isincs %mIRCd.modeMinus) { var %mIRCd.modeMinus = $removecs(%mIRCd.modeMinus,%mIRCd.modeChar) }

                                mIRCd.chan.update %mIRCd.modeChan Limit %mIRCd.modeArgToken
                              }
                              /*
                              else {
                                if (%mIRCd.modeArgToken isnum 1-) {
                                  if (%mIRCd.modeArgToken != $mIRCd.chan(%mIRCd.modeChan,Limit)) {
                                  }
                                  else { }
                                }
                                else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2,$+(%mIRCd.modeFlag,%mIRCd.modeChar)) }
                              }
                              */
                            }
                          }
                          else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2,$+(%mIRCd.modeFlag,%mIRCd.modeChar)) }
                        }
                        elseif ($poscs(ps,%mIRCd.modechar) != $null) {
                          if ($has_modeSet(%mIRCd.modeChan,%mIRCd.modeChar).chan == $false) {
                            mIRCd.chan.update %mIRCd.modeChan Modes $+($mIRCd.chan(%mIRCd.modeChan,Modes),%mIRCd.modeChar)
                            var %mIRCd.modePlus = $+(%mIRCd.modePlus,%mIRCd.modeChar)
                            if (%mIRCd.modeChar isincs %mIRCd.modeMinus) { var %mIRCd.modeMinus = $removecs(%mIRCd.modeMinus,%mIRCd.modeChar) }
                            ; ,-> Now we make sure the polar opposite mode isn't set. +p cannot be set as well as +s. So make sure only one is selected.
                            var %mIRCd.modePolar = $iif(%mIRCd.modeChar === p,s,p)
                            if ($has_modeSet(%mIRCd.modeChan,%mIRCd.modePolar).chan == $true) {
                              mIRCd.chan.update %mIRCd.modeChan Modes $removecs($mIRCd.chan(%mIRCd.modeChan,Modes),%mIRCd.modePolar)
                              var %mIRCd.modeMinus = $+(%mIRCd.modeMinus,%mIRCd.modePolar)
                              if (%mIRCd.modePolar isincs %mIRCd.modePlus) { var %mIRCd.modePlus = $removecs(%mIRCd.modePlus,%mIRCd.modePolar) }
                            }
                          }
                        }
                        elseif ($poscs(imntuCNS,%mIRCd.modeChar) != $null) {
                          if ($has_modeSet(%mIRCd.modeChan,%mIRCd.modeChar).chan == $false) {
                            mIRCd.chan.update %mIRCd.modeChan Modes $+($mIRCd.chan(%mIRCd.modeChan,Modes),%mIRCd.modeChar)
                            var %mIRCd.modePlus = $+(%mIRCd.modePlus,%mIRCd.modeChar)
                            if (%mIRCd.modeChar isincs %mIRCd.modeMinus) { var %mIRCd.modeMinus = $removecs(%mIRCd.modeMinus,%mIRCd.modeChar) }
                          }
                        }
                        else { mIRCd.sraw $1 $mIRCd.reply(501,$mIRCd.nick($1),%mIRCd.modeChar) }
                      }
                    }
                  }
                  if ($calc(($len(%mIRCd.modeMinus) + $len(%mIRCd.modePlus)) - 2) >= $mIRCd(MODESPL)) {
                    if (%mIRCd.modePlus != +) { var %mIRCd.modeString = $v1 }
                    if (%mIRCd.modeMinus != -) { var %mIRCd.modeString = $+(%mIRCd.modeString,$v1) }
                    if (%mIRCd.modeArgPlus != $null) { var %mIRCd.modeString = %mIRCd.modeString $regsubex($str(.,$numtok($v1,32)),/./g,$+($gettok($gettok($v1,\n,32),2,58),$chr(32))) }
                    if (%mIRCd.modeArgMinus != $null) { var %mIRCd.modeString = %mIRCd.modeString $regsubex($str(.,$numtok($v1,32)),/./g,$+($gettok($gettok($v1,\n,32),2,58),$chr(32))) }
                    var %mIRCd.userNumber = 0
                    while (%mIRCd.userNumber < $hcount($mIRCd.chanusers(%mIRCd.modeChan))) {
                      inc %mIRCd.userNumber
                      mIRCd.raw $hget($mIRCd.chanusers(%mIRCd.modeChan),%mIRCd.userNumber).item $+(:,$mIRCd.fulladdr($1)) MODE $3 %mIRCd.modeString
                    }
                    var %mIRCd.modeMinus = -
                    var %mIRCd.modePlus = +
                    var %mIRCd.modeArgMinus = $null
                    var %mIRCd.modeArgPlus = $null
                  }
                }
                if ($calc($len(%mIRCd.modeMinus) + $len(%mIRCd.modePlus)) > 2) {
                  if (%mIRCd.modePlus != +) { var %mIRCd.modeString = $v1 }
                  if (%mIRCd.modeMinus != -) { var %mIRCd.modeString = $+(%mIRCd.modeString,$v1) }
                  if (%mIRCd.modeArgPlus != $null) { var %mIRCd.modeString = %mIRCd.modeString $regsubex($str(.,$numtok($v1,32)),/./g,$+($gettok($gettok($v1,\n,32),2,58),$chr(32))) }
                  if (%mIRCd.modeArgMinus != $null) { var %mIRCd.modeString = %mIRCd.modeString $regsubex($str(.,$numtok($v1,32)),/./g,$+($gettok($gettok($v1,\n,32),2,58),$chr(32))) }
                  var %mIRCd.userNumber = 0
                  while (%mIRCd.userNumber < $hcount($mIRCd.chanusers(%mIRCd.modeChan))) {
                    inc %mIRCd.userNumber
                    mIRCd.raw $hget($mIRCd.chanusers(%mIRCd.modeChan),%mIRCd.userNumber).item $+(:,$mIRCd.fulladdr($1)) MODE $3 %mIRCd.modeString
                  }
                }
              }
              else { mIRCd.sraw $1 $mIRCd.reply(482,$mIRCd.nick($1),$3) }
            }
            else { mIRCd.sraw $1 $mIRCd.reply(442,$mIRCd.nick($1),$3) }
          }
        }
        else {
          if ($is_inUse($3).chan == $true) {
            var %mIRCd.modeChan = $getChanID($3)

            /*
            if ($is_hiddenChan(%mIRCd.modeChan) == $true) {
              if ($is_onChan(%mIRCd.modeChan,$1) == $true) { var %mIRCd.modeFlag = 1 }
              else { var %mIRCd.modeFlag = 0 }
            }
            else { var %mIRCd.modeFlag = 1 }
            */

            var %mIRCd.modeArgs = $iif($poscs($mIRCd.chan(%mIRCd.modeChan,Modes),k) < $poscs($mIRCd.chan(%mIRCd.modeChan,Modes),l),$mIRCd.chan(%mIRCd.modeChan,Key) $mIRCd.chan(%mIRCd.modeChan,Limit),$mIRCd.chan(%mIRCd.modeChan,Limit) $mIRCd.chan(%mIRCd.modeChan,Key))
            ; `-> Temporary until rescripted.

            mIRCd.sraw $1 $mIRCd.reply(324,$mIRCd.nick($1),$3,$mIRCd.chan(%mIRCd.modeChan,Modes)) $iif(%mIRCd.modeArgs != $null,$v1)
            mIRCd.sraw $1 $mIRCd.reply(329,$mIRCd.nick($1),$3,$mIRCd.chan(%mIRCd.modeChan,CreateTS))

            ; Show more stuff like they key if they're on it. (Though +l is visible.)
            ; And even then, the key and limit need to be shown in the correct order. E.g. +kl key 5, +lk 5 key
          }
          else {
            ; `-> NO SUCH CHANNEL
          }
        }
      }
      else {
        ; `-> NO SUCH CHANNEL
      }
    }
    else {
      ; `-> Target is the user.
      if ($3 == $mIRCd.nick($1)) {
        if ($4 != $null) {
          var %mIRCd.modeFlag = $null
          var %mIRCd.modeMinus = -
          var %mIRCd.modePlus = +
          var %mIRCd.modeNumber = 0
          while (%mIRCd.modeNumber < $len($4)) {
            inc %mIRCd.modeNumber
            var %mIRCd.modeChar = $mid($4,%mIRCd.modeNumber,1)
            if (%mIRCd.modeFlag == $null) {
              if ($pos(-+,%mIRCd.modeChar) != $null) { var %mIRCd.modeFlag = %mIRCd.modeChar }
            }
            else {
              if ($pos(-+,%mIRCd.modeChar) != $null) { var %mIRCd.modeFlag = %mIRCd.modeChar }
              else {
                if (%mIRCd.modeFlag == -) {
                  if ($poscs(dgikopswCDISWX,%mIRCd.modeChar) != $null) {
                    if ($has_modeSet($1,%mIRCd.modeChar).user == $true) {
                      mIRCd.user.update $1 Modes $removecs($mIRCd.user($1,Modes),%mIRCd.modeChar)
                      var %mIRCd.modeMinus = $+(%mIRCd.modeMinus,%mIRCd.modeChar)
                      if (%mIRCd.modeChar isincs %mIRCd.modePlus) { var %mIRCd.modePlus = $removecs(%mIRCd.modePlus,%mIRCd.modeChar) }

                      if ($poscs(io,%mIRCd.modeChar) != $null) { hdel $mIRCd.mode(%mIRCd.modeChar) $1 }
                      ; `-> This, sadly, is an incredibly hacky way of keeping track of how many +i/+o users there are.
                    }
                  }
                  else {
                    if (%mIRCd.modeChar !== x) { mIRCd.sraw $1 $mIRCd.reply(501,$mIRCd.nick($1),%mIRCd.modeChar) }
                    ; `-> +x can never be unset once it has been set. But we don't want it to return "no such mode," either.
                  }
                }
                else {
                  if ($poscs(gkWX,%mIRCd.modeChar) != $null) {
                    if ($has_modeSet($1,o).user == $true) {
                      if ($has_modeSet($1,%mIRCd.modeChar).user == $false) {
                        mIRCd.user.update $1 Modes $+($mIRCd.user($1,Modes),%mIRCd.modeChar)
                        var %mIRCd.modePlus = $+(%mIRCd.modePlus,%mIRCd.modeChar)
                        if (%mIRCd.modeChar isincs %mIRCd.modeMinus) { var %mIRCd.modeMinus = $removecs(%mIRCd.modeMinus,%mIRCd.modeChar) }
                      }
                    }
                    else { mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.nick($1)) }
                  }

                  elseif (%mIRCd.modeChar === s) {
                    if ($has_modeSet($1,%mIRCd.modeChar).user == $false) {
                      mIRCd.user.update $1 Modes $+($mIRCd.user($1,Modes),%mIRCd.modeChar)
                      var %mIRCd.modePlus = $+(%mIRCd.modePlus,%mIRCd.modeChar)
                      if (%mIRCd.modeChar isincs %mIRCd.modeMinus) { var %mIRCd.modeMinus = $removecs(%mIRCd.modeMinus,%mIRCd.modeChar) }

                      ; +s +256...

                      ; mIRCd.user.update $1 SNOMASK $mIRCd($+(DEFAULT_SNOMASK_,$iif($has_modeSet($1,o).user == $true,OPER,USER)))
                    }
                    else {
                      ; `-> SNOMASK change.
                    }

                  }
                  elseif ($poscs(dipwxCDIS,%mIRCd.modeChar) != $null) {
                    if ($has_modeSet($1,%mIRCd.modechar).user == $false) {
                      mIRCd.user.update $1 Modes $+($mIRCd.user($1,Modes),%mIRCd.modeChar)
                      var %mIRCd.modePlus = $+(%mIRCd.modePlus,%mIRCd.modeChar)
                      if (%mIRCd.modeChar isincs %mIRCd.modeMinus) { var %mIRCd.modeMinus = $removecs(%mIRCd.modeMinus,%mIRCd.modeChar) }

                      if (%mIRCd.modeChar === i) { hadd -m $mIRCd.mode(%mIRCd.modeChar) $1 1 }
                      ; `-> Ditto.

                      if (%mIRCd.modeChar === x) {
                        ; `-> Obfuscate the host.
                        if ($bool_fmt($mIRCd(HIDE_HOSTS_FREELY)) == $true) {
                          var %mIRCd.userHost = $mIRCd.user($1,Host)
                          mIRCd.user.update $1 Host $mIRCd.hidehost($mIRCd.user($1,TrueHost))
                          mIRCd.user.spoofquit $1 %mIRCd.userHost $mIRCd.user($1,Host) $mIRCd.registered
                          mIRCd.sraw $1 $mIRCd.reply(396,$mIRCd.nick($1),$mIRCd.user($1,Host))
                        }
                      }

                    }
                  }
                  else {
                    if (%mIRCd.modeChar !== o) { mIRCd.sraw $1 $mIRCd.reply(501,$mIRCd.nick($1),%mIRCd.modeChar) }
                    ; `-> +o can never be set. But we also don't want to to return "no such mode," either.
                  }
                }
              }
            }
          }
          if ($calc($len(%mIRCd.modeMinus) + $len(%mIRCd.modePlus)) > 2) {
            if (%mIRCd.modePlus != +) { var %mIRCd.modeString = $v1 }
            if (%mIRCd.modeMinus != -) { var %mIRCd.modeString = $+(%mIRCd.modeString,$v1) }
            mIRCd.raw $1 $+(:,$mIRCd.fulladdr($1)) MODE $mIRCd.nick($1) %mIRCd.modeString
          }
        }
        else { mIRCd.sraw $1 $mIRCd.reply(221,$mIRCd.nick($1),$mIRCd.user($1,Modes)) }
      }
      else {
        if ($has_modeSet($1,o).user == $true) {
          if ($4 == $null) { mIRCd.sraw $1 $mIRCd.reply(221,$3,$mIRCd.user($getSockname($3),Modes)) }
          else { mIRCd.sraw $1 $mIRCd.reply(502,$mIRCd.nick($1)) }
        }
        else { mIRCd.raw $1 $mIRCd.reply(502,$mIRCd.nick($1)) }
      }
    }
  }
  else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
}

alias -l mIRCd_command_motd {
  ; /mIRCd_command_motd <sockname>

  if (($isfile($mIRCd.file.motd) == $true) && ($lines($mIRCd.file.motd) > 0)) {
    mIRCd.sraw $1 $mIRCd.reply(375,$mIRCd.nick($1))
    mIRCd.sraw $1 $mIRCd.reply(372,$mIRCd.nick($1),$asctime($file($mIRCd.file.motd).mtime,dd/mm/yyyy HH:nn))
    ; `-> I believe the line showing the last time the motd file was updated is in fact optional.
    var %mIRCd.lineNumber = 0
    while (%mIRCd.lineNumber < $lines($mIRCd.file.motd)) {
      inc %mIRCd.lineNumber
      mIRCd.sraw $1 $mIRCd.reply(372,$mIRCd.nick($1),$read($mIRCd.file.motd, n, %mIRCd.lineNumber))
    }
    mIRCd.sraw $1 $mIRCd.reply(376,$mIRCd.nick($1))
  }
  else { mIRCd.sraw $1 $mIRCd.reply(422,$mIRCd.nick($1)) }
}

alias -l mIRCd_command_names {
  ; /mIRCd_command_names <sockname> NAMES [-d] <#chan[,#chan,#chan,...]>

  ; Note: -d has not been added as of yet.

  if ($3 != $null) {
    var %mIRCd.namesNumber = 0
    while (%mIRCd.namesNumber < $numtok($3,44)) {
      inc %mIRCd.namesNumber
      var %mIRCd.namesName = $gettok($3,%mIRCd.namesNumber,44)
      if ($is_inUse(%mIRCd.namesName).chan == $true) {
        var %mIRCd.namesChan = $getChanID(%mIRCd.namesName)
        var %mIRCd.chanFlag = =
        var %mIRCd.namesFlag = 1
        if ($has_modeSet(%mIRCd.namesChan,p).chan == $true) {
          var %mIRCd.chanFlag = *
          if ($is_onChan(%mIRCd.namesChan,$1) == $false) { var %mIRCd.namesFlag = 2 }
        }
        if ($has_modeSet(%mIRCd.namesChan,s).chan == $true) {
          var %mIRCd.chanFlag = @
          if ($is_onChan(%mIRCd.namesChan,$1) == $false) { var %mIRCd.namesFlag = 0 }
        }
        if ($has_modeSet($1,o).user == $true) { var %mIRCd.namesFlag = 1 }
        if (%mIRCd.namesFlag > 0) {
          var %mIRCd.userNumber = 0, %mIRCd.namesString = $null
          while (%mIRCd.userNumber < $hcount($mIRCd.chanusers(%mIRCd.namesChan))) {
            inc %mIRCd.userNumber
            var %mIRCd.userSock = $hget($mIRCd.chanusers(%mIRCd.namesChan),%mIRCd.userNumber).item

            /*
            if ($has_modeSet(%mIRCd.userSock,i).user == $true) {
            }
            */

            var %mIRCd.namesString = %mIRCd.namesString $+($modePrefs(%mIRCd.namesChan,%mIRCd.userSock),$mIRCd.fulladdr(%mIRCd.userSock))

            if ($numtok(%mIRCd.namesString,32) == 7) {
              ; `-> I've opted for a hard coded 7 here. I've seen this vary on numerous IRCds (from around 6~8 per line with a n!u@h) though.
              mIRCd.sraw $1 $mIRCd.reply(353,$mIRCd.nick($1),%mIRCd.chanFlag,%mIRCd.namesName,%mIRCd.namesString)
              var %mIRCd.namesString = $null
            }
          }
          if (%mIRCd.namesString != $null) { mIRCd.sraw $1 $mIRCd.reply(353,$mIRCd.nick($1),%mIRCd.chanFlag,%mIRCd.namesName,%mIRCd.namesString) }
        }
        mIRCd.sraw $1 $mIRCd.reply(366,$mIRCd.nick($1),%mIRCd.namesName)
      }
      else { mIRCd.sraw $1 $mIRCd.reply(366,$mIRCd.nick($1),%mIRCd.namesName) }
    }
  }
  else { mIRCd.sraw $1 $mIRCd.reply(366,$mIRCd.nick($1),*) }
}

alias -l mIRCd_command_nick {
  ; /mIRCd_command_nick <sockname> NICK [:]<new nick>

  if ($3 != $null) {
    var %mIRCd.nickName = $left($iif($left($3,1) == :,$right($3,-1),$3),$mIRCd(MAXNICKLEN))
    if ($is_valid(%mIRCd.nickName).nick == $true) {
      if ($is_inUse(%mIRCd.nickName).nick == $false) {
        if ($is_illegal(%mIRCd.nickName).nick == $false) {
          var %mIRCd.userNumber = 0
          while (%mIRCd.userNumber < $hcount($mIRCd.users)) {
            inc %mIRCd.userNumber
            var %mIRCd.userSock = $hget($mIRCd.users,%mIRCd.userNumber).item
            if ($on_mutualChan($1,%mIRCd.userSock) == $true) { mIRCd.raw %mIRCd.userSock $+(:,$mIRCd.fulladdr($1)) NICK %mIRCd.nickName }
          }
          mIRCd.map.nick $1 %mIRCd.nickName
        }
        else { }
      }
      else { }
    }
    else { }
  }
  else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
}

alias -l mIRCd_command_notice {
  ; /mIRCd_command_notice <sockname> NOTICE <target[,target,target,...]> :<message>

  if ($3 != $null) {
    if ($4- != $null) {
      mIRCd.user.update $1 IdleTS $ctime
      ; `-> Doesn't matter if the message gets sent or not - E.g. trying to send a message to a channel which is +m but you lack status. It still counts.
      var %mIRCd.notNumber = 0
      while (%mIRCd.notNumber < $numtok($3,44)) {
        inc %mIRCd.notNumber
        var %mIRCd.notName = $gettok($3,%mIRCd.notNumber,44)
        if ($istok($gettok($3,$+($calc(%mIRCd.notNumber - 1),--),44),%mIRCd.notName,44) == $false) {
          ; `-> Send to the target once, and once only. Otherwise we wind up with /notice #chan,#chan,#chan Hi! displaying "Hi!" in #chan three times.
          if ($is_valid(%mIRCd.notName).chan == $true) {
            ; `-> Target is a channel.
            if ($is_inUse(%mIRCd.notName).chan == $true) {
              var %mIRCd.notChan = $getChanID(%mIRCd.notName)
              var %mIRCd.notFlag = 1
              ; +b
              if ($has_modeSet(%mIRCd.notChan,n).chan == $true) {
                if ($is_onChan(%mIRCd.notChan,$1) == $false) {
                  var %mIRCd.notFlag = 0
                  mIRCd.sraw $1 $mIRCd.reply(404,$mIRCd.nick($1),%mIRCd.notName,$parenthesis(+n))
                }
              }
              if ($has_modeSet(%mIRCd.notChan,m).chan == $true) {
                if ($has_chanStatus(%mIRCd.notChan,$1) == $false) {
                  var %mIRCd.notFlag = 0
                  mIRCd.sraw $1 $mIRCd.reply(404,$mIRCd.nick($1),%mIRCd.notName,$parenthesis(+m))
                }
              }
              if (%mIRCd.notFlag == 1) {
                var %mIRCd.userNumber = 0
                while (%mIRCd.userNumber < $hcount($mIRCd.chanusers(%mIRCd.notChan))) {
                  inc %mIRCd.userNumber
                  var %mIRCd.notSock = $hget($mIRCd.chanusers(%mIRCd.notChan),%mIRCd.userNumber).item
                  if (%mIRCd.notSock != $1) {
                    if ($has_modeSet(%mIRCd.notSock,d).user == $false) { mIRCd.raw %mIRCd.notSock $+(:,$mIRCd.fulladdr($1)) NOTICE %mIRCd.notName $colonize($iif($has_modeSet(%mIRCd.msgChan,S).chan == $true,$strip($4-),$4-)) }
                    ; `-> Don't display to deaf (+d) users.
                  }
                  ; `-> Don't display to the sender.
                }
              }
            }
            else {
            }
          }
          else {
            ; `-> Target is a user.
            if ($is_inUse(%mIRCd.notName).nick == $true) {
              var %mIRCd.notSock = $getSockname(%mIRCd.notName)
              ; +D?
              mIRCd.raw %mIRCd.notSock $+(:,$mIRCd.fulladdr($1)) NOTICE %mIRCd.notName $colonize($iif($has_modeSet(%mIRCd.notSock,S).user == $true,$strip($4-),$4-))
            }
            else { }
          }
        }
      }
    }
  }
  else { }
}

alias -l mIRCd_command_oper {
  ; /mIRCd_command_oper <sockname> OPER <account> <password>

  if ($3 != $null) {
    if ($is_operAccount($3) == $true) {
      if ($4 != $null) {
        if ($mIRCd.mkpasswd($4) === $thisOperPassword($3)) {
          if ($has_modeSet($1,o).user == $false) {
            mIRCd.dwallops $mIRCd.nick($1) $parenthesis($gettok($mIRCd.fulladdr($1),2-,33)) is now an IRC operator (o) using UID $3
            mIRCd.user.update $1 Modes $+($mIRCd.user($1,Modes),o)
            hadd -m $mIRCd.mode(o) $1 1
            ; `-> This is a hacky way of keeping track of opers on the server for use within /lusers.
            mIRCd.raw $1 $+(:,$mIRCd.fulladdr($1)) MODE $mIRCd.nick($1) +o
            mIRCd.sraw $1 $mIRCd.reply(381,$mIRCd.nick($1))
          }
        }
        else {
          mIRCd.dwallops Failed $upper($2) attempt by $mIRCd.nick($1) $parenthesis($gettok($mIRCd.fulladdr($1),2-,33)) using UID $3
          mIRCd.sraw $1 $mIRCd.reply(491,$mIRCd.nick($1))
        }
      }
      else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
    }
    else { mIRCd.sraw $1 $mIRCd.reply(464,$mIRCd.nick($1)) }
  }
  else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
}

alias -l mIRCd_command_part {
  ; /mIRCd_command_part <sockname> PART <#chan[,#chan,#chan,...]> :[part message]

  if ($3 != $null) {
    var %mIRCd.partNumber = 0
    while (%mIRCd.partNumber < $numtok($3,44)) {
      inc %mIRCd.partNumber
      var %mIRCd.partName = $gettok($3,%mIRCd.partNumber,44)
      if ($is_inUse(%mIRCd.partName).chan == $true) {
        var %mIRCd.partChan = $getChanID(%mIRCd.partName)
        if ($is_onChan(%mIRCd.partChan,$1) == $true) {
          var %mIRCd.userNumber = 0
          while (%mIRCd.userNumber < $hcount($mIRCd.chanusers(%mIRCd.partChan))) {
            inc %mIRCd.userNumber
            var %mIRCd.partSock = $hget($mIRCd.chanusers(%mIRCd.partChan),%mIRCd.userNumber).item
            ; +u?
            mIRCd.raw %mIRCd.partSock $+(:,$mIRCd.fulladdr($1)) PART %mIRCd.partName $4-
            mIRCd.chan.user.del %mIRCd.partChan $1
          }
        }
        else {
        }
      }
      else {
      }
    }
  }
  else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
}

alias -l mIRCd_command_ping {
  ; /mIRCd_command_ping <sockname> PING [...]

  if ($3 != $null) {
    mIRCd.sraw $1 PONG $mIRCd(SERVER_NAME) $3
    mIRCd.user.update $1 LastAck $ctime
  }
  else { }
}
alias -l mIRCd_command_pong {
  ; /mIRCd_command_pong <sockname> PONG [...]

  mIRCd.user.update $1 LastAck $ctime
}
; `-> Not entirely sure if anything else is needed for this command.

alias -l mIRCd_command_privmsg {
  ; /mIRCd_command_privmsg <sockname> PRIVMSG <target[,target,target,...]> :<message>

  if ($3 != $null) {
    if ($4- != $null) {
      mIRCd.user.update $1 IdleTS $ctime
      ; `-> Doesn't matter if the message gets sent or not - E.g. trying to send a message to a channel which is +m but you lack status. It still counts.
      var %mIRCd.msgNumber = 0
      while (%mIRCd.msgNumber < $numtok($3,44)) {
        inc %mIRCd.msgNumber
        var %mIRCd.msgName = $gettok($3,%mIRCd.msgNumber,44)
        if ($istok($gettok($3,$+($calc(%mIRCd.msgNumber - 1),--),44),%mIRCd.msgName,44) == $false) {
          ; `-> Send to the target once, and once only. Otherwise we wind up with /msg #chan,#chan,#chan Hi! displaying "Hi!" in #chan three times.
          if ($is_valid(%mIRCd.msgName).chan == $true) {
            ; `-> Target is a channel.
            if ($is_inUse(%mIRCd.msgName).chan == $true) {
              var %mIRCd.msgChan = $getChanID(%mIRCd.msgName)
              var %mIRCd.msgFlag = 1
              ; +b
              if ($has_modeSet(%mIRCd.msgChan,n).chan == $true) {
                if ($is_onChan(%mIRCd.msgChan,$1) == $false) {
                  var %mIRCd.msgFlag = 0
                  mIRCd.sraw $1 $mIRCd.reply(404,$mIRCd.nick($1),%mIRCd.msgName,$parenthesis(+n))
                }
              }
              if ($has_modeSet(%mIRCd.msgChan,m).chan == $true) {
                if ($has_chanStatus(%mIRCd.msgChan,$1) == $false) {
                  var %mIRCd.msgFlag = 0
                  mIRCd.sraw $1 $mIRCd.reply(404,$mIRCd.nick($1),%mIRCd.msgName,$parenthesis(+m))
                }
              }
              if ($has_modeSet(%mIRCd.msgChan,C).chan == $true) {
                if ($chr(1) isincs $4-) {
                  if ($+(:,$chr(1),ACTION*,$chr(1)) !iswm $4-) {
                    var %mIRCd.msgFlag = 0
                    mIRCd.sraw $1 $mIRCd.reply(404,$mIRCd.nick($1),%mIRCd.msgName,$parenthesis(No CTCP's (+C)))
                  }
                  ; `-> Despite starting with a control code, /me is permitted.
                }
              }

              if (%mIRCd.msgFlag == 1) {
                var %mIRCd.userNumber = 0
                while (%mIRCd.userNumber < $hcount($mIRCd.chanusers(%mIRCd.msgChan))) {
                  inc %mIRCd.userNumber
                  var %mIRCd.msgSock = $hget($mIRCd.chanusers(%mIRCd.msgChan),%mIRCd.userNumber).item
                  if (%mIRCd.msgSock != $1) {
                    if ($has_modeSet(%mIRCd.msgSock,d).user == $false) { mIRCd.raw %mIRCd.msgSock $+(:,$mIRCd.fulladdr($1)) PRIVMSG %mIRCd.msgName $colonize($iif($has_modeSet(%mIRCd.msgChan,S).chan == $true,$strip($4-),$4-)) }
                    ; `-> Don't display to deaf (+d) users.
                  }
                  ; `-> Don't display to the sender.
                }
              }
            }
            else {
            }
          }
          else {
            ; `-> Target is a user.
            if ($is_inUse(%mIRCd.msgName).nick == $true) {
              var %mIRCd.msgSock = $getSockname(%mIRCd.msgName)
              if ($has_modeSet(%mIRCd.msgSock,D).user == $false) { mIRCd.raw %mIRCd.msgSock $+(:,$mIRCd.fulladdr($1)) PRIVMSG %mIRCd.msgName $colonize($iif($has_modeSet(%mIRCd.msgSock,S).user == $true,$strip($4-),$4-)) }
              else {
              }
            }
            else {
            }
          }
        }
      }
    }
    else {
    }
  }
  else { }
}

alias -l mIRCd_command_quit {
  ; /mIRCd_command_quit <sockname> QUIT :[message]

  mIRCd.user.disconnect 0 $1 $3-
}

alias -l mIRCd_command_time {
  ; /mIRCd_command_time <sockname>

  mIRCd.sraw $1 $mIRCd.reply(391,$mIRCd.nick($1))
}

alias -l mIRCd_command_topic {
  ; /mIRCd_command_topic <sockname> TOPIC <#chan[,#chan,#chan,...]> [:[topic]]

  if ($3 != $null) {
    var %mIRCd.topicNumber = 0
    while (%mIRCd.topicNumber < $numtok($3,44)) {
      inc %mIRCd.topicNumber
      var %mIRCd.topicName = $gettok($3,%mIRCd.topicNumber,44)
      if ($is_inUse(%mIRCd.topicName).chan == $true) {
        var %mIRCd.topicChan = $getChanID(%mIRCd.topicName)
        if ($is_onChan(%mIRCd.topicChan,$1) == $true) {
          if ($4- != $null) {
            var %mIRCd.topicFlag = 1
            if ($has_modeSet(%mIRCd.topicChan,t).chan == $true) {
              if ($has_chanStatus(%mIRCd.topicChan,$1,o) == $false) { var %mIRCd.topicFlag = 0 }
            }

            if (%mIRCd.topicFlag == 1) {
              if ($4- == :) {
                ; if ($mIRCd.chan(%mIRCd.topicChan,Topic) != $null) {
                mIRCd.chan.unset %mIRCd.topicChan Topic
                mIRCd.chan.unset %mIRCd.topicChan TopicTS
                mIRCd.chan.unset %mIRCd.topicChan TopicBy
                ; }
              }
              else {
                mIRCd.chan.update %mIRCd.topicChan Topic $left($right($4-,-1),$mIRCd(TOPICLEN))
                mIRCd.chan.update %mIRCd.topicChan TopicTS $ctime
                mIRCd.chan.update %mIRCd.topicChan TopicBy $mIRCd.fulladdr($1)
              }
              var %mIRCd.userNumber = 0
              while (%mIRCd.userNumber < $hcount($mIRCd.chanusers(%mIRCd.topicChan))) {
                inc %mIRCd.userNumber
                mIRCd.raw $hget($mIRCd.chanusers(%mIRCd.topicChan),%mIRCd.userNumber).item $+(:,$mIRCd.fulladdr($1)) TOPIC %mIRCd.topicName $+(:,$mIRCd.chan(%mIRCd.topicChan,Topic))
              }
            }
            else { mIRCd.sraw $1 $mIRCd.reply(482,$mIRCd.nick($1),%mIRCd.topicName) }
          }
          else {
            if ($mIRCd.chan(%mIRCd.topicChan,Topic) != $null) {
              mIRCd.sraw $1 $mIRCd.reply(332,$mIRCd.nick($1),%mIRCd.topicName,$mIRCd.chan(%mIRCd.topicChan,Topic))
              mIRCd.sraw $1 $mIRCd.reply(333,$mIRCd.nick($1),%mIRCd.topicName,$mIRCd.chan(%mIRCd.topicChan,TopicBy),$mIRCd.chan(%mIRCd.topicChan,TopicTS))
            }
            else { mIRCd.sraw $1 $mIRCd.reply(331,$mIRCd.nick($1),%mIRCd.topicName) }
          }
        }
        else {
          if ($has_modeSet(%mIRCd.topicChan,s).chan == $false) {
            ; `-> +p channel(s) do show the topic according to an Undernet FAQ.
            if ($mIRCd.chan(%mIRCd.topicChan,Topic) != $null) {
              mIRCd.sraw $1 $mIRCd.reply(332,$mIRCd.nick($1),%mIRCd.topicName,$mIRCd.chan(%mIRCd.topicChan,Topic))
              mIRCd.sraw $1 $mIRCd.reply(333,$mIRCd.nick($1),%mIRCd.topicName,$mIRCd.chan(%mIRCd.topicChan,TopicBy),$mIRCd.chan(%mIRCd.topicChan,TopicTS))
            }
            else { mIRCd.sraw $1 $mIRCd.reply(331,$mIRCd.nick($1),%mIRCd.topicName) }
          }
          else {
            ; `-> "No such channel."
          }
        }
      }
      else {
        ; `-> No such channel.
      }
    }
  }
  else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
}

alias -l mIRCd_command_user {
  ; /mIRCd_command_user <sockname>

  mIRCd.sraw $1 $mIRCd.reply(462,$mIRCd.nick($1))
}
; `-> Just tell the user that they can't reregister.

alias -l mIRCd_command_version {
  ; /mIRCd_command_version <sockname>

  mIRCd.sraw $1 $mIRCd.reply(351,$mIRCd.nick($1))
  mIRCd.005 $1
}

alias -l mIRCd_command_wallops {
  ; /mIRCd_command_wallops <sockname> WALLOPS <message>

  if ($has_modeSet($1,o).user == $true) {
    if ($3- != $null) {
      var %mIRCd.wallopsString = :* $iif($left($3-,1) == :,$right($3-,-1),$3-)
      var %mIRCd.userNumber = 0
      while (%mIRCd.userNumber < $hcount($mIRCd.users)) {
        inc %mIRCd.userNumber
        var %mIRCd.wallopsSock = $hget($mIRCd.users,%mIRCd.userNumber).item
        if (($has_modeSet(%mIRCd.wallopsSock,o).user == $true) && ($has_modeSet(%mIRCd.wallopsSock,w).user == $true)) { mIRCd.raw %mIRCd.wallopsSock $+(:,$mIRCd.fulladdr($1)) WALLOPS %mIRCd.wallopsString }
      }
    }
    else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
  }
  else { mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.nick($1)) }
}

alias -l mIRCd_command_wallusers {
  ; /mIRCd_command_wallusers <sockname> WALLUSERS <message>

  if ($has_modeSet($1,o).user == $true) {
    if ($3- != $null) {
      var %mIRCd.wallusersString = $+(:,$chr(36)) $iif($left($3-,1) == :,$right($3-,-1),$3-)
      var %mIRCd.userNumber = 0
      while (%mIRCd.userNumber < $hcount($mIRCd.users)) {
        inc %mIRCd.userNumber
        var %mIRCd.wallusersSock = $hget($mIRCd.users,%mIRCd.userNumber).item
        if ($has_modeSet(%mIRCd.wallusersSock,w).user == $true) { mIRCd.raw %mIRCd.wallusersSock $+(:,$mIRCd.fulladdr($1)) WALLOPS %mIRCd.wallusersString }
      }
    }
    else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
  }
  else { mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.nick($1)) }
}

alias -l mIRCd_command_whois {
  ; /mIRCd_command_whois <sockname> WHOIS <nick[,nick,nick,...]>

  if ($3 != $null) {
    var %mIRCd.whoisNumber = 0
    while (%mIRCd.whoisNumber < $numtok($3,44)) {
      inc %mIRCd.whoisNumber
      var %mIRCd.whoisName = $gettok($3,%mIRCd.whoisNumber,44)
      if ($is_inUse(%mIRCd.whoisName).nick == $true) {
        var %mIRCd.whoisSock = $getSockname(%mIRCd.whoisName)
        mIRCd.sraw $1 $mIRCd.reply(311,$mIRCd.nick($1),$mIRCd.nick(%mIRCd.whoisSock),$mIRCd.user(%mIRCd.whoisSock,User),$mIRCd.user(%mIRCd.whoisSock,Host),$mIRCd.user(%mIRCd.whoisSock,RealName))


        if ($mIRCd.user(%mIRCd.whoisSock,Chans) != $null) {
          var %mIRCd.v1 = $v1
          if (($has_modeSet($1,o).user == $true) || (%mIRCd.whoisName == $mIRCd.nick($1))) { var %mIRCd.whoisChans = $regsubex(%mIRCd.v1,/./g,$+($iif($has_modeSet(%mIRCd.whoisSock,d).user == $true,-),$modePrefs($+(mIRCd.chan.,$gettok(%mIRCd.v1,\n,44)),%mIRCd.whoisSock),$mIRCd.chan($+(mIRCd.chan.,$gettok(%mIRCd.v1,\n,44)),Name),$chr(32))) }
          ; `-> IRC operators can see hidden channels in a /whois afaik. And users can see their own channels regardless.
          else {
            if ($has_modeSet(%mIRCd.whoisSock,p).user == $false) { var %mIRCd.whoisChans = $regsubex(%mIRCd.v1,/./g,$iif($is_hiddenChan($+(mIRCd.chan.,$gettok(%mIRCd.v1,\n,44))) == $false,$+($iif($has_modeSet(%mIRCd.whoisSock,d).user == $true,-),$modePrefs($+(mIRCd.chan.,$gettok(%mIRCd.v1,\n,44)),%mIRCd.whoisSock),$mIRCd.chan($+(mIRCd.chan.,$gettok(%mIRCd.v1,\n,44)),Name),$chr(32)))) }
            ; `-> Don't show channels if the user has +p set. Also, hidden channels need to be shown if the channels are shared.
          }
          if ($remove(%mIRCd.whoisChans, $chr(32)) != $null) { mIRCd.sraw $1 $mIRCd.reply(319,$mIRCd.nick($1),$mIRCd.nick(%mIRCd.whoisSock),%mIRCd.whoisChans) }
          ; `-> This code is quite ugly, sorry.
        }

        ; `-> FIX THIS


        mIRCd.sraw $1 $mIRCd.reply(312,$mIRCd.nick($1),$mIRCd.nick(%mIRCd.whoisSock),$mIRCd(SERVER_NAME),$mIRCd(NETWORK_INFO))
        if ($has_modeSet(%mIRCd.whoisSock,o).user == $true) { mIRCd.sraw $1 $mIRCd.reply(313,$mIRCd.nick($1),$mIRCd.nick(%mIRCd.whoisSock)) }
        if ($has_modeSet(%mIRCd.whoisSock,k).user == $true) { mIRCd.sraw $1 $mIRCd.reply(310,$mIRCd.nick($1),$mIRCd.nick(%mIRCd.whoisSock)) }
        ; 330
        if ((%mIRCd.whoisName == $mIRCd.nick($1)) || ($has_modeSet($1,o).user == $true)) { mIRCd.sraw $1 $mIRCd.reply(338,$mIRCd.nick($1),$mIRCd.nick(%mIRCd.whoisSock),$+($mIRCd.user(%mIRCd.whoisSock,User),@,$mIRCd.user(%mIRCd.whoisSock,TrueHost)),$sock(%mIRCd.whoisSock).ip) }
        if ($has_modeSet(%mIRCd.whoisSock,D).user == $true) { mIRCd.sraw $1 $mIRCd.reply(316,$mIRCd.nick($1),$mIRCd.nick(%mIRCd.whoisSock)) }
        if ($mIRCd.user(%mIRCd.whoisSock,Away) != $null) { mIRCd.sraw $1 $mIRCd.reply(301,$mIRCd.nick($1),$mIRCd.nick(%mIRCd.whoisSock),$mIRCd.user(%mIRCd.whoisSock,Away)) }

        mIRCd.sraw $1 $mIRCd.reply(317,$mIRCd.nick($1),$mIRCd.nick(%mIRCd.whoisSock),$iif($mIRCd.user(%mIRCd.whoisSock,IdleTS) != $null,$calc($ctime - $v1),$sock(%mIRCd.whoisSock).to),$calc($ctime - $sock(%mIRCd.whoisSock).to))

        if (($has_modeSet(%mIRCd.whoisSock,W).user == $true) && (%mIRCd.whoisName != $mIRCd.nick($1))) { mIRCd.sraw %mIRCd.whoisSock NOTICE %mIRCd.whoisName :*** $mIRCd.nick($1) is performing a $+(/,$upper($2)) on you. }
      }
      else {
      }
    }
    mIRCd.sraw $1 $mIRCd.reply(318,$mIRCd.nick($1),$3)
  }
  else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.nick($1),$2) }
}



; mIRCd Functions (Generic)

alias -l colonize {
  ; $colonize(<text>)

  return $iif($left($1-,1) == :,$1-,$+(:,$1-))
}
alias -l decolonize {
  ; $decolonize(<text>)

  return $iif($left($1-,1) == :,$right($1-,-1),$1-)
}

alias -l divisibleMask {
  ; $divisibleMask(<N>)

  if ($1 > 0) {
    var %maskNumber = $1, %baseNumber = 0, %baseFlags = 65536,32768,16384,8192,4096,2048,1024,512,256,128,64,32,16,8,4,2,1,0, %maskOutput = $null
    while (%baseNumber < $numtok(%baseFlags,44)) {
      inc %baseNumber
      if ($calc(%maskNumber % $gettok(%baseFlags,%baseNumber,44)) != %maskNumber) { var %maskNumber = $v1, %maskOutput = %maskOutput $gettok(%baseFlags,%baseNumber,44) }
    }
  }
  return $iif(%maskOutput != $null,$v1,0)
}

alias -l getChanID {
  ; $getChanID(<#chan>)

  return $hfind($mIRCd.chans, $1, 1).data
}
alias -l getSockname {
  ; $getSockname(<nick>)

  return $hfind($mIRCd.users, $1, 1).data
}

alias -l has_chanStatus {
  ; $has_chanStatus(<chan ID>,<sockname>[,mode char])

  if ($3 != $null) { return $bool_fmt($gettok($hget($mIRCd.chanusers($1),$2),$calc($poscs(ohv,$3) + 2),32)) }
  else { return $bool_fmt($count($gettok($hget($mIRCd.chanusers($1),$2),3-5,32),1)) }
}

alias -l has_modeSet {
  ; $has_modeSet(<target>,<mode char>)[.chan|.user]

  if ($prop == chan) { return $iif($2 isincs $mIRCd.chan($1,Modes),$true,$false) }
  if ($prop == user) { return $iif($2 isincs $mIRCd.user($1,Modes),$true,$false) }
}

alias -l is_bannedFrom {
  ; $is_bannedFrom(<chan ID>,<sockname>)
}

alias -l is_hiddenChan {
  ; $is_hiddenChan(<chan ID>)

  if ((p isincs $mIRCd.chan($1,Modes)) || (s isincs $mIRCd.chan($1,Modes))) { return $true }
  else { return $false }
}
alias -l is_illegal {
  ; $is_illegal(<target>)[.chan|.nick]

  if ($prop == chan) { var %hashTable = $mIRCd.badchans }
  if ($prop == nick) { var %hashTable = $mIRCd.badnicks }
  return $iif($hfind(%hashTable, $1, 1, W).data != $null,$true,$false)
}
alias -l is_inUse {
  ; $is_inUse(<target>)[.chan|.nick]

  if ($prop == chan) { var %hashTable = $mIRCd.chans }
  if ($prop == nick) { var %hashTable = $mIRCd.users }
  return $iif($hfind(%hashTable, $1, 1).data != $null,$true,$false)
}

alias -l is_invitePending {
  ; $is_invitePending(<chan ID>,<sockname>)

  return $istok($mIRCd.user($2,Invites),$gettok($1,-1,46),44)
}

alias -l is_onChan {
  ; $is_onChan(<chan ID>,<sockname>)

  if ($hget($mIRCd.chanusers($1),$2) != $null) { return $true }
  else { return $false }
}

alias -l is_operAccount {
  ; $is_operAccount(<arg>)

  if ($hget($mIRCd.opers,$1) != $null) { return $true }
  else { return $false }
}

alias -l on_mutualChan {
  ; $on_mutualChan(<sockname>,<sockname>)

  var %mIRCd.chans.1 = $mIRCd.user($1,Chans)
  var %mIRCd.chans.2 = $mIRCd.user($2,Chans)
  return $iif($count($regsubex($str(.,$numtok(%mIRCd.chans.1,44)),/./g,$iif($istok(%mIRCd.chans.2,$gettok(%mIRCd.chans.1,\n,44),44) == $true,1,0)),1) > 0,$true,$false)
}

alias -l is_valid {
  ; $is_valid(<arg>)[.chan|.key|.nick]

  if ($prop == chan) {
    var %regex = /([#][^\x07\x2C\s])/
    return $bool_fmt($regex($1,%regex))
  }

  if ($prop == key) {
    return $true
  }
  if ($prop == nick) {
    var %regex = /^([][A-Za-z_\\^`{|}][][\w\\^`{|}-]*)$/
    return $bool_fmt($regex($1,%regex))
  }
  if ($prop == nuh) { }
  if ($prop == uh) { }
}
alias -l legalizeIdent {
  ; $legalizeIdent(<ident>)

  return $regsubex($1,/([^a-zA-Z0-9_.-])/gu,_)
}

alias -l modePrefs {
  ; $modePrefs(<chan ID>,<sockname>)

  return $regsubex($removecs($gettok($hget($mIRCd.chanusers($1),$2),3-,32),$chr(32)),/(.)/g,$iif(\t == 1,$mid(@%+,\n,1)))
}

alias -l thisOperPassword {
  ; $thisOperPassword(<arg>)

  return $hget($mIRCd.opers, $1)
}

; mIRCd Functions (mIRCd named series)

alias -l mIRCd {
  ; $mIRCd(<item>)

  return $hget(mIRCd,$1)
}

alias -l mIRCd.005 {
  ; /mIRCd.005 <sockname>

  ; ,-> Limited to 13 items per line.
  var %mIRCd.005.1 = $+(AWAYLEN=,$mIRCd(AWAYLEN)) CASEMAPPING=rfc1459 CHANTYPES=# $+(KICKLEN=,$mIRCd(KICKLEN)) $+(MAXCHANNELS=,$mIRCd(MAXCHANNELS)) $+(MAXNICKLEN=,$mIRCd(MAXNICKLEN)) $+(MODES=,$mIRCd(MODESPL)) NAMESX $+(NETWORK=,$mIRCd(NETWORK_NAME)) $+(NICKLEN=,$mIRCd(MAXNICKLEN)) PREFIX=(ohv)@%+ STATUSMSG=@%+ $+(TOPICLEN=,$mIRCd(TOPICLEN))
  mIRCd.sraw $1 $mIRCd.reply(005,$mIRCd.nick($1),%mIRCd.005.1)
  var %mIRCd.005.2 = UHNAMES
  mIRCd.sraw $1 $mIRCd.reply(005,$mIRCd.nick($1),%mIRCd.005.2)
  ; var %mIRCd.005.3 =
  ; ...
}

alias -l mIRCd.chan {
  ; $mIRCd.chan(<ID>,<item>)

  return $hget($+(mIRCd[,$1,]),$2)
}

alias -l mIRCd.chan.create {
  ; /mIRCd.chan.create <#chan> <sockname>

  var %mIRCd.chanNumber = 1
  while ($hfind($mIRCd.chans,$+(mIRCd.chan.,%mIRCd.chanNumber),0,W) > 0) { inc %mIRCd.chanNumber }
  var %mIRCd.chanID = $+(mIRCd.chan.,%mIRCd.chanNumber)

  hadd -m $mIRCd.chans %mIRCd.chanID $1

  mIRCd.chan.update %mIRCd.chanID CreateTS $ctime
  mIRCd.chan.update %mIRCd.chanID Name $1

  mIRCd.chan.update %mIRCd.chanID Modes nt

  mIRCd.chan.user.add %mIRCd.chanID $2
}

alias -l mIRCd.chan.destruct {
  ; /mIRCd.chan.destruct <chan ID>

  ; hfree $mIRCd.banlist($1)

  hdel $mIRCd.chans $1
  hfree $mIRCd.chanusers($1)
  hfree $+(mIRCd[,$1,])
}


alias -l mIRCd.chan.unset {
  ; /mIRCd.chan.unset <chan ID> <item>

  hdel $+(mIRCd[,$1,]) $2
}
alias -l mIRCd.chan.update {
  ; /mIRCd.chan.update <chan ID> <item> <value>

  hadd -m $+(mIRCd[,$1,]) $2 $3-
}


alias -l mIRCd.chan.user.add {
  ; /mIRCd.chan.user.add <chan ID> <sockname>

  var %mIRCd.theseFlags = 1 0 0
  if ($hget($mIRCd.chanusers($1)) != $null) {
    if ($hcount($mIRCd.chanusers($1)) > 0) { var %mIRCd.theseFlags = 0 0 0 }
  }

  hadd -m $mIRCd.chanusers($1) $2 $ctime 1 %mIRCd.theseFlags
  ; `-> timeJoined isVisible* opState hopState voiceState (*Incase I add +d/D at a later date.)

  if ($istok($mIRCd.user($2,Chans),$gettok($1,-1,46),44) == $false) { mIRCd.user.update $2 Chans $iif($mIRCd.user($2,Chans) != $null,$+($v1,$comma,$gettok($1,-1,46)),$gettok($1,-1,46)) }

  var %mIRCd.chanName = $mIRCd.chan($1,Name)
  var %mIRCd.userNumber = 0
  while (%mIRCd.userNumber < $hcount($mIRCd.chanusers($1))) {
    inc %mIRCd.userNumber
    var %mIRCd.sockName = $hget($mIRCd.chanusers($1),%mIRCd.userNumber).item
    mIRCd.raw %mIRCd.sockName $+(:,$mIRCd.fulladdr($2)) JOIN %mIRCd.chanName
  }

  if ($mIRCd.chan($1,Topic) != $null) { mIRCd_command_topic $2 TOPIC %mIRCd.chanName }

  mIRCd_command_names $2 NAMES %mIRCd.chanName
}


alias -l mIRCd.chan.user.del {
  ; /mIRCd.chan.user.del <chan ID> <sockname>

  hdel $mIRCd.chanusers($1) $2
  if (($hcount($mIRCd.chanusers($1)) <= 0) && ($has_modeSet($1,P).chan == $false)) { mIRCd.chan.destruct $1 }
  ; `-> Only destroy the channel if +P isn't set.
  mIRCd.user.update $2 Chans $remtok($mIRCd.user($2,Chans),$gettok($1,-1,46),1,44)
}

alias -l mIRCd.chan.user.update {
  ; /mIRCd.chan.user.update <chan ID> <sockname> <value> <token>

  hadd -m $mIRCd.chanusers($1) $2 $puttok($hget($mIRCd.chanusers($1),$2),$3,$4,32)
}




alias -l mIRCd.commands {
  ; $mIRCd.commands([0|1|2])

  if ($1 == 0) { return NICK,PONG,QUIT,USER }
  elseif ($1 == 1) { return ADMIN,AWAY,CLEARMODE,HASH,HELP,INVITE,ISON,JOIN,KICK,KILL,LIST,LUSERS,MKPASSWD,MODE,MOTD,NAMES,NICK,NOTICE,OPER,PART,PING,PONG,PRIVMSG,QUIT,TIME,TOPIC,USER,VERSION,WALLOPS,WALLUSERS,WHOIS }
  ; elseif ($1 == 2) { return }
  ; `-> Server.
  ; else { return ADMIN,PING,PONG,QUIT }
  ; `-> User is shunned.
}

alias -l mIRCd.dwallops {
  ; /mIRCd.dwallops <text>

  var %mIRCd.userNumber = 0
  while (%mIRCd.userNumber < $hcount($mIRCd.users)) {
    inc %mIRCd.userNumber
    var %mIRCd.dwallopsSock = $hget($mIRCd.users,%mIRCd.userNumber).item
    if ($has_modeSet(%mIRCd.dwallopsSock,g).user == $true) {
      mIRCd.sraw %mIRCd.dwallopsSock WALLOPS $+(:,$1-)
    }
  }
}

alias -l mIRCd.file.bad.chans { return $qt($scriptdirconf\chans.403) }
alias -l mIRCd.file.bad.nicks { return $qt($scriptdirconf\nicks.403) }
alias -l mIRCd.file.bad.words { return $qt($scriptdirconf\words.403) }
alias -l mIRCd.file.conf { return $qt($scriptdirmIRCd.ini) }
alias -l mIRCd.file.help { return $qt($+($scriptdirhelp\,$1,.help)) }
alias -l mIRCd.file.motd { return $qt($scriptdirmIRCd.motd) }
alias -l mIRCd.file.raws { return $qt($scriptdirconf\mIRCd.raws) }

alias -l mIRCd.fulladdr {
  ; $mIRCd.fulladdr(<sockname>)

  return $+($mIRCd.user($1,Nick),!,$mIRCd.user($1,User),@,$mIRCd.user($1,Host))
}

alias -l mIRCd.hidehost {
  ; $mIRCd.hidehost(<arg>)

  return $+($gettok($regsubex($upper($hmac($sha1($1), $+($longip($1),:,$mIRCd(SALT)), sha512)),/(.{8})/g,\1.),1-3,46),.IP)
}

alias -l mIRCd.ident.destruct {
  ; /mIRCd.ident.destruct <sockname>

  if ($hget($mIRCd.ident,$hget($mIRCd.ident,$1).item).item != $null) { hdel $mIRCd.ident $v1 }
  if ($sock($1) != $null) { sockclose $1 }
}
alias -l mIRCd.map.nick {
  ; /mIRCd.map.nick <sockname> <nick>

  hadd -m $mIRCd.users $1 $2
  mIRCd.user.update $1 Nick $2
}

alias -l mIRCd.mkpasswd {
  ; $mIRCd.mkpasswd(<arg>)

  return $hmac($sha1($1), $+($1,:,$mIRCd(SALT)), sha512)
}

alias -l mIRCd.modes {
  ; $mIRCd.modes(<chan|user>)

  if ($1 == chan) { return bhiklmnopstuvCNOPS bhklov }
  elseif ($1 == user) { return dgikopswxCDISWX }
}

alias -l mIRCd.nick {
  ; $mIRCd.nick(<sockname>)

  return $iif($mIRCd.user($1,Nick) != $null,$v1,*)
}
alias -l mIRCd.raw {
  ; /mIRCd.raw <sockname> <args>

  if ($window($mIRCd.window) != $null) { echo -ci2t "Info text" $v1 * $1 <- $2- }
  sockwrite -nt $1 $2-
}
alias -l mIRCd.register {
  ; /mIRCd.register <sockname>

  mIRCd.user.update $1 PassPing $base($rand(0,999999999999),10,10,12)
  mIRCd.raw $1 PING $+(:,$mIRCd.user($1,PassPing))
}

alias -l mIRCd.snotice {
  ; /mIRCd.snotice <snomask> <text>

  var %mIRCd.userNumber = 0
  while (%mIRCd.userNumber < $hcount($mIRCd.users)) {
    inc %mIRCd.userNumber
    var %mIRCd.snoticeSock = $hget($mIRCd.users,%mIRCd.userNumber).item
    if ($has_modeSet(%mIRCd.snoticeSock,s).user == $true) {
      if ($istok($divisibleMask($mIRCd.user(%mIRCd.snoticeSock,SNOMASK)),$1,32) == $true) { mIRCd.sraw %mIRCd.snoticeSock NOTICE $mIRCd.nick(%mIRCd.snoticeSock) :*** Notice -- $2- }
    }
  }
}

alias -l mIRCd.sraw {
  ; /mIRCd.sraw <sockname> <args>

  if ($window($mIRCd.window) != $null) { echo -ci2t "Info text" $v1 * $1 <- $2- }
  sockwrite -nt $1 $+(:,$mIRCd(SERVER_NAME)) $2-
}
alias -l mIRCd.user {
  ; $mIRCd.user(<sockname>,<item>)

  return $hget($+(mIRCd[,$1,]),$2)
}
alias -l mIRCd.user.create {
  ; /mIRCd.user.create <sockname> <name of listening socket>

  hadd -m $mIRCd.pre $1 1
  mIRCd.user.update $1 IsRegistered 0
  mIRCd.user.update $1 ThruSock $2
  sockaccept $1
  mIRCd.sraw $1 NOTICE * :*** Processing your connection to $+($mIRCd(SERVER_NAME),...)
  mIRCd.user.update $1 SnoMask $mIRCd(DEFAULT_SNOMASK_USER)
  mIRCd.user.update $1 Host $sock($1).ip
  mIRCd.user.update $1 TrueHost $sock($1).ip
  ; `-> We have to accept the socket first before we can add the host(s).
  if ($bool_fmt($mIRCd(USE_IDENT_SERVER)) == $true) {
    var %mIRCd.identSock = $+(mIRCd.ident.,$gettok($1,-1,46))
    hadd -m $mIRCd.ident %mIRCd.identSock $sock($1).port $+ , $gettok($2,-1,46)
    sockopen %mIRCd.identSock $sock($1).ip 113
  }
}
alias -l mIRCd.user.destruct {
  ; /mIRCd.user.destruct <sockname>

  mIRCd.ident.destruct $+(mIRCd.ident.,$gettok($1,-1,46))
  hdel $mIRCd.users $1
  hfree $+(mIRCd[,$1,])
  if ($hget($mIRCd.mode(i),$1) != $null) { hdel $mIRCd.mode(i) $1 }
  if ($hget($mIRCd.mode(o),$1) != $null) { hdel $mIRCd.mode(o) $1 }
}

alias -l mIRCd.user.disconnect {
  ; /mIRCd.user.disconnect <flag> <sockname> [quit message]

  ; 0 = NORMAL
  ; 1 = ERROR
  ; 2 = KILL
  ; 4 = GLINE

  if ($bool_fmt($mIRCd.user($2,IsRegistered)) == $true) {

    mIRCd.snotice 16384 Client exiting: $mIRCd.nick($2) $parenthesis($gettok($mIRCd.fulladdr($2),2-,33) ... $bracket($sock($2).ip))
    ; `-> Make sure this doesn't show if the flag > 0 - not sure about 1, though.

    if ($mIRCd.user($2,Chans) != $null) {
      if ($1 == 0) { var %mIRCd.quitString = $iif($bool_fmt($mIRCd(PREFIX_QUIT)) == $true,Quit:) }
      var %mIRCd.quitString = %mIRCd.quitString $iif($3-,$v1,$mIRCd.noMessage)

      var %mIRCd.userNumber = 0
      while (%mIRCd.userNumber < $hcount($mIRCd.users)) {
        inc %mIRCd.userNumber
        var %mIRCd.userSock = $hget($mIRCd.users,%mIRCd.userNumber).item
        if ($on_mutualChan($1,%mIRCd.userSock) == $true) {

          mIRCd.raw %mIRCd.userSock $+(:,$mIRCd.fulladdr($2)) QUIT $colonize(%mIRCd.quitString)

        }
      }
      var %mIRCd.chanNumber = 0
      var %mIRCd.userChans = $mIRCd.user($2,Chans)
      while (%mIRCd.chanNumber < $numtok(%mIRCd.userChans,44)) {
        inc %mIRCd.chanNumber
        mIRCd.chan.user.del $+(mIRCd.chan.,$gettok(%mIRCd.userChans,%mIRCd.chanNumber,44)) $2
      }
    }
  }

  if ($1 == 1) { mIRCd.raw $2 ERROR :Closing Link: $mIRCd.nick($2) $bracket($gettok($mIRCd.fulladdr($2),2-,33)) by $mIRCd(SERVER_NAME) $parenthesis($3-) }
  if ($1 == 2) {
    mIRCd.sraw $2 KILL $mIRCd.nick($2) $colonize($3-)
    mIRCd.raw $2 ERROR :Closing Link: $mIRCd.nick($2) $bracket($gettok($mIRCd.fulladdr($2),2-,33)) by $mIRCd(SERVER_NAME) (Killed $parenthesis($3-) $+ )
  }
  ; `-> Check appearance.

  mIRCd.user.destruct $2
  sockclose $2
}

alias -l mIRCd.user.spoofquit {
  ; /mIRCd.user.spoofquit <sockname> <previous host> <new host> :[quit message]

  if ($mIRCd.user($1,Chans) != $null) {
    var %mIRCd.fulladdr = $+($mIRCd.nick($1),!,$mIRCd.user($1,User),@)
    var %mIRCd.userNumber = 0
    while (%mIRCd.userNumber < $hcount($mIRCd.users)) {
      inc %mIRCd.userNumber
      var %mIRCd.userSock = $hget($mIRCd.users,%mIRCd.userNumber).item
      if (%mIRCd.userSock != $1) {
        if ($on_mutualChan($1,%mIRCd.userSock) == $true) { mIRCd.raw %mIRCd.userSock $+(:,%mIRCd.fulladdr,$1) QUIT $+(:,$2-) }
      }
    }
    var %mIRCd.chanNumber = 0
    while (%mIRCd.chanNumber < $numtok($mIRCd.user($1,Chans),44)) {
      inc %mIRCd.chanNumber
      var %mIRCd.chanID = $+(mIRCd.chan.,$gettok($mIRCd.user($1,Chans),%mIRCd.chanNumber,44))
      var %mIRCd.userNumber = 0
      while (%mIRCd.userNumber < $hcount($mIRCd.chanusers(%mIRCd.chanID))) {
        inc %mIRCd.userNumber
        var %mIRCd.joinSock = $hget($mIRCd.chanusers(%mIRCd.chanID),%mIRCd.userNumber).item
        if (%mIRCd.joinSock != $1) {
          mIRCd.raw %mIRCd.joinSock $+(:,%mIRCd.fulladdr,$2) JOIN $mIRCd.chan(%mIRCd.chanID,Name)
        }
      }
    }
  }
}
; `-> When a user does +x and they: * Quits: (Registered)

alias -l mIRCd.user.unset {
  ; /mIRCd.user.unset <sockname> <item>

  hdel $+(mIRCd[,$1,]) $2
}
alias -l mIRCd.user.update {
  ; /mIRCd.user.update <sockname> <item> <value>

  hadd -m $+(mIRCd[,$1,]) $2 $3-
}
alias -l mIRCd.version { return mIRCd(0.03) }
alias -l mIRCd.window { return @mIRCd }

; Operation

alias mIRCd.check {
  ; /mIRCd.check
}

alias mIRCd.die {
  ; /mIRCd.die [nick]

  if ($1 != $null) { var %mIRCd.dieName = $v1 }

  mIRCd.snotice 0 Terminating IRCd. $iif(%mIRCd.dieName != $null,Instruction receieved from $+($v1,.))

  sockclose -w mIRCd.*
  ; `-> Temporary?

  hfree $mIRCd.chans
  hfree -w mIRCd[*][Users]
  hfree $mIRCd.ident
  hfree -w mIRCd[mode_*]
  hfree $mIRCd.pre
  hfree $mIRCd.servers
  hfree $mIRCd.users
  ; `-> Change to a while loop.

  hdel mIRCd START_TS
}

alias mIRCd.load {
  ; /mIRCd.load

  ; `-> /mIRCd.check first?

  if ($isfile($mIRCd.file.conf) == $true) {
    var %mIRCd.sectionLoaded = 0
    if ($ini($mIRCd.file.conf, Server) != $null) {
      hload -im mIRCd $mIRCd.file.conf Server
      inc %mIRCd.sectionLoaded
    }
    if ($ini($mIRCd.file.conf, Mechanics) != $null) {
      hload -im mIRCd $mIRCd.file.conf Mechanics
      inc %mIRCd.sectionLoaded
    }
    if ($ini($mIRCd.file.conf, Features) != $null) {
      hload -im mIRCd $mIRCd.file.conf Features
      inc %mIRCd.sectionLoaded
    }
    ; `-> Required.
    if (%mIRCd.sectionLoaded < 3) {
      hfree mIRCd
      echo -ae [mIRCd]: Error - Required sections missing from $mIRCd.file.conf - aborting load.
      goto mIRCd_load_end
    }

    if ($ini($mIRCd.file.conf, Admin) != $null) { hload -im mIRCd $mIRCd.file.conf Admin }
    if ($ini($mIRCd.file.conf, Opers) != $null) { hload -im $mIRCd.opers $mIRCd.file.conf Opers }
    ; `-> Optional.
  }

  if ($isfile($mIRCd.file.raws) == $true) { hload -m $mIRCd.replies $mIRCd.file.raws }
  ; `-> Required.

  if ($isfile($mIRCd.file.bad.chans) == $true) { hload -mn $mIRCd.badchans $mIRCd.file.bad.chans }
  if ($isfile($mIRCd.file.bad.nicks) == $true) { hload -mn $mIRCd.badnicks $mIRCd.file.bad.nicks }
  if ($isfile($mIRCd.file.bad.words) == $true) { hload -mn $mIRCd.badwords $mIRCd.file.bad.words }
  :mIRCd_load_end
}

alias mIRCd.start {
  ; /mIRCd.start

  if (($hget(mIRCd) != $null) && ($hget($mIRCd.replies) != $null)) {
    ; `-> These must exist in order for the IRCd to work.
    var %mIRCd.itemNumber = 0, %mIRCd.openNumber = 0
    while (%mIRCd.itemNumber < $numtok($mIRCd(CLIENT_PORTS),44)) {
      inc %mIRCd.itemNumber
      var %mIRCd.portNumber = $gettok($mIRCd(CLIENT_PORTS),%mIRCd.itemNumber,44)
      if (%mIRCd.portNumber isnum 1-65536) {
        if ($portfree(%mIRCd.portNumber) == $true) {
          socklisten $+(mIRCd.,%mIRCd.portNumber) %mIRCd.portNumber
          inc %mIRCd.openNumber
        }
        else { echo -ae [mIRCd]: Error - Port %mIRCd.portNumber is already in use. }
      }
    }
    if (%mIRCd.openNumber > 0) {
      hadd -m $mIRCd.servers $mIRCd(SERVER_NAME) 1
      ; `-> Temporary until corrected.

      if ($mIRCd(START_TS) == $null) { hadd -m mIRCd START_TS $ctime }
      ; `-> Make sure not to reset the epoch if already running.
    }
  }
  else { echo -ae [mIRCd]: Error - Could not start mIRCd. Config files have not been loaded or are missing. }
}

; Hash Tables

alias -l mIRCd.badchans { return mIRCd[BadChans] }
alias -l mIRCd.badnicks { return mIRCd[BadNicks] }
alias -l mIRCd.badwords { return mIRCd[BadWords] }
alias -l mIRCd.chans { return mIRCd[Chans] }
alias -l mIRCd.chanusers { return $+(mIRCd[,$1,][Users]) }
alias -l mIRCd.ident { return mIRCd[Ident] }
alias -l mIRCd.mode { return $+(mIRCd[mode_,$1,]) }
alias -l mIRCd.pre { return mIRCd[Pre] }
alias -l mIRCd.opers { return mIRCd[Opers] }
alias -l mIRCd.replies { return mIRCd[Replies] }
alias -l mIRCd.servers { return mIRCd[Servers] }
alias -l mIRCd.users { return mIRCd[Users] }

; Replies

alias -l mIRCd.reply {
  ; $mIRCd.reply(<numeric>,<nick>[,<args>[,...,...]])

  return $1 $2 [ [ $hget($mIRCd.replies,$1) ] ]
}

alias -l mIRCd.hideQuit { return Signed off }
alias -l mIRCd.noMessage { return Disconnected }
alias -l mIRCd.pingTimeout { return Ping timeout }
alias -l mIRCd.registered { return Registered }
alias -l mIRCd.socketClosed { return Remote socket closed the connection }
alias -l mIRCd.socketError { return Socket error }

; Generic Functions

alias -l bool_fmt { return $iif($istok(1 true,$1,32) == $true,$true,$false) }
alias -l bracket { return [[ $+ $1- $+ ]] }
alias -l comma { return $chr(44) }
alias -l hcount { return $hget($1,0).item }
alias -l parenthesis { return ( $+ $1- $+ ) }
#mIRCd end

; Debug User

alias -l debugger.window { return @Debugger }
on *:sockopen:Debugger:{
  sockwrite -nt $sockname NICK :Debugger
  sockwrite -nt $sockname USER Debugger 0 0 :4D7e8b9u10g11g12e13r
}
on *:sockread:Debugger:{
  var %Debugger.sockRead = $null
  sockread %Debugger.sockRead
  tokenize 32 %Debugger.sockRead

  if ($window($debugger.window) != $null) { echo -ci2t "Info text" $v1 > $1- }

  if ($1 == PING) { sockwrite -nt $sockname PONG $2- }
}

; EOF
