; mIRCd_chanHandle.mrc
;
; This script contains the following command(s): INVITE, JOIN, KICK, KNOCK, NAMES, PART, SVSJOIN, SVSPART, TOPIC

alias mIRCd_command_invite {
  ; /mIRCd_command_invite <sockname> INVITE [<nick> <#chan>]

  if ($3 == $null) {
    ; `-> Return any outstanding invite(s).
    if ($mIRCd.info($1,invites) == $null) {
      mIRCd.sraw $1 $mIRCd.reply(347,$mIRCd.info($1,nick))
      return
    }
    var %this.sock = $1
    tokenize 44 $v1
    scon -r mIRCd.sraw %this.sock $!mIRCd.reply(346,$mIRCd.info(%this.sock,nick), $!mIRCd.info( $* ,name) )
    ; `-> A quick and dirty loop.
    mIRCd.sraw %this.sock $mIRCd.reply(347,$mIRCd.info(%this.sock,nick))
    return
  }
  if ($4 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.id = $getChanID($4), %this.name = $iif($mIRCd.info(%this.id,name) != $null,$v1,$4)
  if ($is_on(%this.id,$1) == $false) {
    ; `-> DENY_SECRET doesn't apply here.
    if ($is_modeSet($1,X).nick == $false) {
      mIRCd.sraw $1 $mIRCd.reply(442,$mIRCd.info($1,nick),%this.name)
      return
    }
  }
  if ($is_modeSet(%this.id,Y).chan == $true) {
    if ($is_modeSet($1,X).nick == $false) {
      mIRCd.sraw $1 $mIRCd.reply(598,$mIRCd.info($1,nick),%this.name)
      return
    }
  }
  var %this.sock = $getSockname($3)
  if (%this.sock == $null) {
    mIRCd.sraw $1 $mIRCd.reply(401,$mIRCd.info($1,nick),$3)
    return
  }
  var %this.nick = $mIRCd.info(%this.sock,nick)
  if ($is_on(%this.id,%this.sock) == $true) {
    mIRCd.sraw $1 $mIRCd.reply(443,$mIRCd.info($1,nick),%this.nick,%this.name)
    return
  }
  if (($is_modeSet(%this.id,y).chan == $false) && ($is_op(%this.id,$1) == $false) && ($is_hop(%this.id,$1) == $false) && ($is_modeSet($1,X).nick == $false)) {
    mIRCd.sraw $1 $mIRCd.reply(482,$mIRCd.info($1,nick),%this.name)
    return
  }
  mIRCd.raw %this.sock $+(:,$mIRCd.fulladdr($1)) INVITE %this.nick $+(:,%this.name)
  mIRCd.raw $1 $mIRCd.reply(341,$mIRCd.info($1,nick),%this.nick,%this.name)
  if ($istok($mIRCd.info(%this.sock,invites),%this.id,44) == $true) { return }
  mIRCd.updateUser %this.sock invites $+(%this.id,$comma,$mIRCd.info(%this.sock,invites))
}
alias mIRCd_command_join {
  ; /mIRCd_command_join <sockname> JOIN <0|#chan[,#chan,#chan,...]> [key[,key,key,...]]

  if ($3 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.joins = $3
  if ($hget($mIRCd.targMax,TARGMAX_JOIN) isnum 1-) { var %this.joins = $deltok(%this.joins,$+($calc($v1 + 1),-),44) }
  if ($istok(%this.joins,0,44) == $true) {
    ; `-> Do not join any given channels before 0. Part the ones they're currently in, then join everything post the last 0 given.
    if ($mIRCd.info($1,chans) == $null) { var %this.flag = 1 }
    if (%this.flag != 1) {
      var %this.chans = $mIRCd.info($1,chans)
      var %this.part = 0
      while (%this.part < $numtok(%this.chans,44)) {
        inc %this.part 1
        mIRCd_command_part $1 PART $mIRCd.info($gettok(%this.chans,%this.part,44),name) $+(:,$mIRCd.joinZero)
      }
    }
    var %this.joins = $gettok(%this.joins,$+($calc($findtok(%this.joins,0,$findtok(%this.joins,0,0,44),44) + 1),-),44)
  }
  if (%this.joins == $null) {
    if ($3 != 0) {
      mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
      return
    }
    ; `-> Maybe they just wanted to join 0?
  }
  var %this.join = 0, %this.keyToken = 0
  while (%this.join < $numtok(%this.joins,44)) {
    inc %this.join 1
    var %this.chan = $gettok($strip($gettok(%this.joins,%this.join,44)),1,160), %this.operBypass = 0
    ; `-> Strip any control codes and ignore everything post $chr(160). (These aren't being dealt with by the regex for some reason...)
    if ($is_valid(%this.chan).chan == $false) {
      mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),%this.chan)
      continue
    }
    if (($is_klineMatch(%this.chan) == $true) || ($is_glineMatch(%this.chan) == $true)) {
      if (($bool_fmt($mIRCd(OPER_BYPASS_BADCHAN)) == $true) && ($is_oper($1) == $true)) { var %this.operBypass = 1 }
      if (%this.operBypass != 1) {
        if ($bool_fmt($mIRCd(WALLOPS_BAD_JOINS)) == $true) { mIRCd.serverWallops $mIRCd.info($1,nick) $parenthesis($gettok($mIRCd.fulladdr($1),2,33)) attempted to join a banned channel: %this.chan }
        mIRCd.sraw $1 $mIRCd.reply(479,$mIRCd.info($1,nick),%this.chan)
        continue
      }
    }
    if ($is_exists(%this.chan).chan == $false) {
      if ($bool_fmt($mIRCd(DENY_CHANNEL_CREATION)) == $true) {
        if ($is_oper($1) == $false) {
          mIRCd.sraw $1 $mIRCd.reply(479,$mIRCd.info($1,nick),%this.chan)
          continue
        }
      }
      var %this.name = $left(%this.chan,$mIRCd(MAXCHANNELLEN))
      ; `-> NOTE: # *is* counted as part of the length. (I checked on another IRCd.)
      mIRCd.createChan %this.name $1
      continue
    }
    if ($numtok($mIRCd.info($1,chans),44) >= $mIRCd(MAXCHANNELS)) {
      mIRCd.sraw $1 $mIRCd.reply(405,$mIRCd.info($1,nick),%this.chan)
      continue
    }
    var %this.id = $getChanID(%this.chan), %this.name = $mIRCd.info(%this.id,name)
    if ($is_on(%this.id,$1) == $true) { continue }
    if ($istok($mIRCd.info($1,invites),%this.id,44) == $true) {
      ; `-> Having an invite bypasses the restrictions below.
      mIRCd.updateUser $1 invites $remtok($mIRCd.info($1,invites),%this.id,1,44)
      goto parseJoin
    }
    if ($is_modeSet($1,X).nick == $true) { goto parseJoin }
    ; `-> Oper override not subject to below.
    if (($is_banMatch(%this.id,$mIRCd.fulladdr($1)) == $true) || ($is_banMatch(%this.id,$mIRCd.ipaddr($1)) == $true) || ($is_banMatch(%this.id,$mIRCd.trueaddr($1)) == $true)) {
      mIRCd.sraw $1 $mIRCd.reply(474,$mIRCd.info($1,nick),%this.name)
      continue
    }
    if ($is_modeSet(%this.id,i).chan == $true) {
      mIRCd.sraw $1 $mIRCd.reply(473,$mIRCd.info($1,nick),%this.name)
      continue
    }
    if (($is_modeSet(%this.id,l).chan == $true) && ($hcount($mIRCd.chanUsers(%this.id)) >= $mIRCd.info(%this.id,limit))) {
      mIRCd.sraw $1 $mIRCd.reply(471,$mIRCd.info($1,nick),%this.name)
      continue
    }
    if (($is_modeSet(%this.id,j).chan == $true) && ($sock($1).to <= $mIRCd.info(%this.id,joinThrottle))) {
      mIRCd.sraw $1 $mIRCd.reply(469,$mIRCd.info($1,nick),%this.name,$calc($mIRCd.info(%this.id,joinThrottle) - $sock($1).to))
      return
    }
    if (($is_modeSet(%this.id,O).chan == $true) && ($is_oper($1) == $false)) {
      mIRCd.sraw $1 $mIRCd.reply(470,$mIRCd.info($1,nick),%this.name)
      continue
    }
    ; ,-> Do +k last due the nature of it.
    if ($is_modeSet(%this.id,k).chan == $true) {
      inc %this.keyToken 1
      var %this.tryKey = $gettok($4,%this.keyToken,44)
      if (%this.tryKey !== $mIRCd.info(%this.id,key)) {
        mIRCd.sraw $1 $mIRCd.reply(475,$mIRCd.info($1,nick),%this.name)
        continue
      }
    }
    :parseJoin
    mIRCd.chanAddUser %this.id $1
  }
}
alias mIRCd_command_kick {
  ; /mIRCd_command_kick <sockname> KICK <#chan> <nick[,nick,nick,...]> :[reason]

  if ($4 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  if ($is_exists($3).chan == $false) {
    mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),$3)
    return
  }
  var %this.id = $getChanID($3), %this.name = $mIRCd.info(%this.id,name)
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
  var %this.kicks = $4
  if ($hget($mIRCd.targMax,TARGMAX_KICK) isnum 1-) { var %this.kicks = $deltok(%this.kicks,$+($calc($v1 + 1),-),44) }
  if (%this.kicks == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.nick = 0
  while (%this.nick < $numtok(%this.kicks,44)) {
    inc %this.nick 1
    var %this.nickname = $gettok(%this.kicks,%this.nick,44), %this.kickSock = $getSockname(%this.nickname)
    if (%this.kickSock == $null) {
      mIRCd.sraw $1 $mIRCd.reply(401,$mIRCd.info($1,nick),%this.nickname)
      continue
    }
    if ($is_on(%this.id,%this.kickSock) == $false) {
      mIRCd.sraw $1 $mIRCd.reply(441,$mIRCd.info($1,nick),%this.name,%this.nickname)
      continue
    }
    if ($is_modeSet(%this.kickSock,k).nick == $true) {
      mIRCd.sraw $1 $mIRCd.reply(484,$mIRCd.info($1,nick),%this.nickname,%this.name)
      continue
    }
    var %this.kick = 0
    while (%this.kick < $hcount($mIRCd.chanUsers(%this.id))) {
      inc %this.kick 1
      var %this.sock = $hget($mIRCd.chanUsers(%this.id),%this.kick).item
      if ($gettok($hget($mIRCd.chanUsers(%this.id),%this.kickSock),2,32) == 1) {
        if (%this.sock != %this.kickSock) {
          mIRCd.raw %this.sock $+(:,$mIRCd.fulladdr(%this.kickSock)) JOIN %this.name
          var %this.d = 1
        }
      }
      mIRCd.raw %this.sock $+(:,$mIRCd.fulladdr($1)) KICK %this.name %this.nickname $colonize($iif($5- != $null,$left($v1,$mIRCd(KICKLEN)),%this.nickname)))
    }
    mIRCd.chanDelUser %this.id %this.kickSock
  }
  if (%this.d == 1) {
    if ($is_modeSet(%this.id,d).chan == $true) { mIRCd.dCheck %this.id }
  }
}
alias mIRCd_command_knock {
  ; /mIRCd_command_knock <sockname> KNOCK <#chan[,#chan,#chan,...]> <message>

  if (($4 == :) || ($4- == $null)) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.knocks = $3
  if ($hget($mIRCd.targMax,TARGMAX_KNOCK) isnum 1-) { var %this.knocks = $deltok(%this.knocks,$+($calc($v1 + 1),-),44) }
  if (%this.knocks == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.loop = 0
  while (%this.loop < $numtok(%this.knocks,44)) {
    inc %this.loop 1
    var %this.knock = $gettok(%this.knocks,%this.loop,44)
    if ($is_exists(%this.knock).chan == $false) {
      mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),%this.knock)
      continue
    }
    var %this.id = $getChanID(%this.knock), %this.name = $mIRCd.info(%this.id,name)
    if ($is_on(%this.id,$1) == $true) {
      mIRCd.sraw $1 $mIRCd.reply(597,$mIRCd.info($1,nick),$2,%this.name,$parenthesis(You're already on this channel))
      continue
    }
    if ($is_open(%this.id,$1) == $true) {
      if (($is_secret(%this.id) == $true) && ($bool_fmt($mIRCd(DENY_SECRET)) == $true)) {
        mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),%this.knock)
        continue
      }
      mIRCd.sraw $1 $mIRCd.reply(597,$mIRCd.info($1,nick),$2,%this.name,$parenthesis(Channel is already open))
      continue
    }
    if ($is_private(%this.id) == $true) {
      mIRCd.sraw $1 $mIRCd.reply(597,$mIRCd.info($1,nick),$2,%this.name,$parenthesis(Channel is private))
      continue
    }
    if (($is_banMatch(%this.id,$mIRCd.fulladdr($1)) == $true) || ($is_banMatch(%this.id,$mIRCd.ipaddr($1)) == $true) || ($is_banMatch(%this.id,$mIRCd.trueaddr($1)) == $true)) {
      if (($is_secret(%this.id) == $true) && ($bool_fmt($mIRCd(DENY_SECRET)) == $true)) {
        mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),%this.knock)
        continue
      }
      mIRCd.sraw $1 $mIRCd.reply(597,$mIRCd.info($1,nick),$2,%this.name,$parenthesis(You are banned))
      continue
    }
    if ($is_modeSet(%this.id,K).chan == $true) {
      if ($is_modeSet($1,X).nick == $false) {
        if (($is_secret(%this.id) == $true) && ($bool_fmt($mIRCd(DENY_SECRET)) == $true)) {
          mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),%this.knock)
          continue
        }
        mIRCd.sraw $1 $mIRCd.reply(597,$mIRCd.info($1,nick),$2,%this.name,$parenthesis($upper($2) not allowed $parenthesis(+K)))
        continue
      }
    }
    var %this.user = 0
    while (%this.user < $hcount($mIRCd.chanUsers(%this.id))) {
      inc %this.user 1
      var %this.sock = $hget($mIRCd.chanUsers(%this.id),%this.user).item
      if ($count($gettok($hget($mIRCd.chanUsers(%this.id),%this.sock),3-4,32),1) > 0) { mIRCd.sraw %this.sock NOTICE $+(@,%this.name) :[Knock] by $mIRCd.fulladdr($1) $parenthesis($left($4-,$mIRCd(TOPICLEN))) }
    }
    mIRCd.sraw $1 NOTICE $mIRCd.info($1,nick) :*** Notice -- Knocked on %this.name
  }
  mIRCd.updateChan %this.id lastActive $ctime
}
alias mIRCd_command_names {
  ; /mIRCd_command_names <sockname> NAMES [-d] <#chan[,#chan,#chan,...]>

  if ($3 == $null) {
    mIRCd.raw $1 $mIRCd.reply(366,$mIRCd.info($1,nick),*)
    return
  }
  if ($3 == -d) {
    var %this.d = $iif(d isincs $mIRCd.chanModes && D isincs $mIRCd.chanModes,1,0)
    if ($4 == $null) {
      mIRCd.raw $1 $mIRCd.reply(366,$mIRCd.info($1,nick),*)
      return
    }
    tokenize 32 $1 $2 $4
    ; `-> It's easier (read as: hackier) to set a flag and retokenize the string.
  }
  var %this.names = $3
  if ($hget($mIRCd.targMax,TARGMAX_NAMES) isnum 1-) { var %this.names = $deltok(%this.names,$+($calc($v1 + 1),-),44) }
  if (%this.names == $null) {
    mIRCd.sraw $1 $mIRCd.reply(366,$mIRCd.info($1,nick),*)
    return
  }
  var %this.loop = 0, %this.offChan = 0
  while (%this.loop < $numtok(%this.names,44)) {
    inc %this.loop 1
    var %this.chan = $gettok(%this.names,%this.loop,44)
    if ($is_exists(%this.chan).chan == $false) { goto processNames }
    var %this.id = $getChanID(%this.chan), %this.name = $mIRCd.info(%this.id,name)
    if ($is_on(%this.id,$1) == $false) {
      if ($is_secret(%this.id) == $true) { goto processNames }
      var %this.offChan = 1
    }
    var %this.flag = $iif($is_private(%this.id) == $true,1,0) $iif($is_secret(%this.id) == $true,1,0), %this.flag = $iif($mid(*@,$findtok(%this.flag,1,1,32),1) != $null,$v1,=)
    ; `-> %this.flag: = means normal (default), * means private, @ means secret
    var %this.user = 0, %this.string = $null
    while (%this.user < $hcount($mIRCd.chanUsers(%this.id))) {
      inc %this.user 1
      var %this.sock = $hget($mIRCd.chanUsers(%this.id),%this.user).item, %this.sockState = $gettok($hget($mIRCd.chanUsers(%this.id),%this.user).data,2,32)
      if (%this.offChan == 1) {
        if (($is_modeSet(%this.sock,i).nick == $true) && (%this.sock != $1)) {
          if ($is_oper($1) == $false) { continue }
        }
        ; `-> I did notice on bircd that /NAMES -d #chan when oper doesn't show invisible users. (Though I believe that might be a bug.)
      }
      var %this.userState = $iif($mIRCd.info($1,NAMESX) == 1,$mIRCd.namesStatus(%this.id,%this.sock),$mIRCd.namesStatus(%this.id,%this.sock).top)
      if (%this.d == 1) {
        if (%this.sockState != 1) { continue }
        if (%this.sock == $1) { continue }
        goto processNamesString
      }
      if ($is_modeSet(%this.id,D).chan == $true) {
        if (%this.sockState == 1) {
          if (%this.sock != $1) { continue }
        }
      }
      if ($is_modeSet(%this.id,d).chan == $true) {
        if (%this.sockState == 1) {
          if (%this.sock != $1) { continue }
        }
        ; `-> Ignore those still invisible.
      }
      :processNamesString
      var %this.string = $+(%this.userState,$iif($mIRCd.info($1,UHNAMES) == 1,$mIRCd.fulladdr(%this.sock),$mIRCd.info(%this.sock,nick))) %this.string
      if ($numtok(%this.string,32) == 8) {
        ; `-> I've opted for a hardcoded eight here. After eight users are in the string, send the line to the user.
        mIRCd.sraw $1 $mIRCd.reply($iif(%this.d == 1,355,353),$mIRCd.info($1,nick),%this.flag,%this.name,%this.string)
        var %this.string = $null
      }
    }
    if (%this.string != $null) { mIRCd.sraw $1 $mIRCd.reply($iif(%this.d == 1,355,353),$mIRCd.info($1,nick),%this.flag,%this.name,%this.string) }
    :processNames
    mIRCd.sraw $1 $mIRCd.reply(366,$mIRCd.info($1,nick),$iif($iif($is_secret(%this.id) == $true && $is_on(%this.id,$1) == $false,%this.chan,%this.name) != $null,$v1,%this.chan))
    if (%this.offChan == 1) { var %this.offChan = 0 }
  }
}
alias mIRCd_command_part {
  ; /mIRCd_command_part <sockname> PART <#chan[,#chan,#chan,...]> :[part message]

  if ($3 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.parts = $3
  if ($hget($mIRCd.targMax,TARGMAX_PART) isnum 1-) { var %this.parts = $deltok(%this.parts,$+($calc($v1 + 1),-),44) }
  if (%this.parts == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.loop = 0
  while (%this.loop < $numtok(%this.parts,44)) {
    inc %this.loop 1
    var %this.chan = $gettok(%this.parts,%this.loop,44)
    if ($is_exists(%this.chan).chan == $false) {
      mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),%this.chan)
      continue
    }
    var %this.id = $getChanID(%this.chan), %this.name = $mIRCd.info(%this.id,name)
    if ($is_on(%this.id,$1) == $false) {
      if (($is_secret(%this.id) == $true) && ($bool_fmt($mIRCd(DENY_SECRET)) == $true)) {
        mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),%this.chan)
        continue
      }
      mIRCd.sraw $1 $mIRCd.reply(442,$mIRCd.info($1,nick),%this.name)
      continue
    }
    var %this.partMessage = $colonize($iif($4-,$v1))
    if (u isincs $mIRCd.info(%this.id,modes)) { var %this.partMessage = $+(:,$mIRCd.standardPart) }
    if ($gettok($hget($mIRCd.chanUsers(%this.id),$1),2,32) == 0) {
      var %this.user = 0
      while (%this.user < $hcount($mIRCd.chanUsers(%this.id))) {
        inc %this.user 1
        mIRCd.raw $hget($mIRCd.chanUsers(%this.id),%this.user).item $+(:,$mIRCd.fulladdr($1)) PART %this.name %this.partMessage
      }
    }
    mIRCd.chanDelUser %this.id $1
  }
}
alias mIRCd_command_svsjoin {
  ; /mIRCd_command_svsjoin <sockname> SVSJOIN <nick> <#chan>

  if ($is_oper($1) == $false) {
    mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
    return
  }
  if ($4 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.sock = $getSockname($3)
  if (%this.sock == $null) {
    mIRCd.sraw $1 $mIRCd.reply(401,$mIRCd.info($1,nick),$3)
    return
  }
  var %this.nick = $mIRCd.info(%this.sock,nick), %this.chan = $gettok($strip($4),1,160)
  if ($is_valid(%this.chan).chan == $false) {
    mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),$4)
    return
  }
  var %this.id = $getChanID(%this.chan), %this.name = $iif(%this.id != $null,$mIRCd.info(%this.id,name),%this.chan)
  if ($is_on(%this.id,%this.sock) == $true) {
    mIRCd.sraw $1 $mIRCd.reply(441,$mIRCd.info($1,nick),%this.nick,%this.name)
    return
  }
  if (($is_klineMatch(%this.chan) == $true) || ($is_glineMatch(%this.chan) == $true)) {
    if (($bool_fmt($mIRCd(OPER_BYPASS_BADCHAN)) == $true) && ($is_oper(%this.sock) == $true)) { var %this.operBypass = 1 }
    if (%this.operBypass != 1) {
      mIRCd.serverWallops Failed $upper($2) to a banned channel by $mIRCd.info($1,nick) $+($parenthesis($gettok($mIRCd.fulladdr($1),2,33)),:) %this.nick -> %this.name
      mIRCd.sraw $1 $mIRCd.reply(479,$mIRCd.info($1,nick),%this.chan)
      return
    }
  }
  if ($is_exists(%this.chan).chan == $false) {
    mIRCd.createChan %this.chan %this.sock
    goto processInfoShare
  }
  mIRCd.chanAddUser %this.id %this.sock
  ; `-> We need to bypass restrictions (+i, etc.), so this is different from SVSPART (which just uses the PART command).
  :processInfoShare
  mIRCd.sraw %this.sock NOTICE %this.nick :*** Notice -- You were forced by $mIRCd.info($1,nick) $parenthesis($gettok($mIRCd.fulladdr($1),2,33)) to join: %this.name
  ; `-> Include the nick and their user@host to prevent abuse. E.g. Rogue opers forcing users to join highly illegal channels or whatever.
  mIRCd.serverWallops $upper($2) by $mIRCd.info($1,nick) $+($parenthesis($gettok($mIRCd.fulladdr($1),2,33)),:) %this.nick -> %this.name
  ; `-> Issue a +g wallops to prevent abuse.
}
alias mIRCd_command_svspart {
  ; /mIRCd_command_svspart <sockname> SVSPART <nick> <#chan>

  if ($is_oper($1) == $false) {
    mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
    return
  }
  if ($4 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.sock = $getSockname($3)
  if (%this.sock == $null) {
    mIRCd.sraw $1 $mIRCd.reply(401,$mIRCd.info($1,nick),$3)
    return
  }
  var %this.nick = $mIRCd.info(%this.sock,nick), %this.chan = $4
  if ($is_valid(%this.chan).chan == $false) {
    mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),%this.chan)
    return
  }
  if ($is_exists(%this.chan).chan == $false) {
    mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),%this.chan)
    return
  }
  var %this.id = $getChanID(%this.chan), %this.name = $iif(%this.id != $null,$mIRCd.info(%this.id,name),%this.chan)
  if ($is_on(%this.id,%this.sock) == $false) {
    mIRCd.sraw $1 $mIRCd.reply(441,$mIRCd.info($1,nick),%this.name,%this.nick)
    return
  }
  mIRCd_command_part %this.sock PART %this.name $+(:,$mIRCd.svsPart)
  mIRCd.sraw %this.sock NOTICE %this.nick :*** Notice -- You were forced to part: %this.name
  ; `-> This one doesn't matter too much.
  mIRCd.serverWallops $upper($2) by $mIRCd.info($1,nick) $+($parenthesis($gettok($mIRCd.fulladdr($1),2,33)),:) %this.nick -> %this.name
  ; `-> Issue a +g wallops to prevent abuse.
}
alias mIRCd_command_topic {
  ; /mIRCd_command_topic <sockname> TOPIC <#chan[,#chan,#chan,...]> :[topic]

  if ($3 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.topics = $3
  if ($hget($mIRCd.targMax,TARGMAX_TOPIC) isnum 1-) { var %this.topics = $deltok(%this.topics,$+($calc($v1 - 1),-),44) }
  if (%this.topics == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.loop = 0
  while (%this.loop < $numtok(%this.topics,44)) {
    inc %this.loop 1
    var %this.target = $gettok(%this.topics,%this.loop,44)
    if ($is_exists(%this.target).chan == $false) {
      mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),%this.target)
      continue
    }
    var %this.id = $getChanID(%this.target), %this.name = $mIRCd.info(%this.id,name)
    if ($4 == $null) {
      if ($is_on(%this.id,$1) == $false) {
        if ($is_secret(%this.id) == $true) {
          mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),%this.target)
          continue
        }
      }
      if ($mIRCd.info(%this.id,topic) == $null) {
        mIRCd.sraw $1 $mIRCd.reply(331,$mIRCd.info($1,nick),%this.name)
        continue
      }
      mIRCd.sraw $1 $mIRCd.reply(332,$mIRCd.info($1,nick),%this.name,$mIRCd.info(%this.id,topic))
      mIRCd.sraw $1 $mIRCd.reply(333,$mIRCd.info($1,nick),%this.name,$mIRCd.info(%this.id,topicBy),$mIRCd.info(%this.id,topicTime))
      continue
    }
    if ($is_on(%this.id,$1) == $false) {
      if ($is_modeSet($1,X).nick == $false) {
        if (($is_secret(%this.id) == $true) && ($bool_fmt($mIRCd(DENY_SECRET)) == $true)) {
          mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),%this.target)
          continue
        }
        mIRCd.sraw $1 $mIRCd.reply(442,$mIRCd.info($1,nick),%this.name)
        continue
      }
    }
    if (($is_modeSet(%this.id,t).chan == $true) && ($is_op(%this.id,$1) == $false) && ($is_hop(%this.id,$1) == $false) && ($is_modeSet($1,X).nick == $false)) {
      mIRCd.sraw $1 $mIRCd.reply(482,$mIRCd.info($1,nick),%this.name)
      continue
    }
    if ($4 === :) {
      ; `-> Remove the topic.
      mIRCd.delChanItem %this.id topic
      mIRCd.delChanItem %this.id topicBy
      mIRCd.delChanItem %this.id topicTime
      var %this.flag = 1
    }
    if (%this.flag != 1) {
      mIRCd.updateChan %this.id topic $right($colonize($4-),-1)
      mIRCd.updateChan %this.id topicBy $mIRCd.fulladdr($1)
      mIRCd.updateChan %this.id topicTime $ctime
    }
    var %this.show = 0, %this.changeState = 0
    while (%this.show < $hcount($mIRCd.chanUsers(%this.id))) {
      inc %this.show 1
      var %this.sock = $hget($mIRCd.chanUsers(%this.id),%this.show).item
      if ($gettok($hget($mIRCd.chanUsers(%this.id),$1),2,32) == 1) {
        if (%this.sock != $1) {
          mIRCd.raw %this.sock $+(:,$mIRCd.fulladdr($1)) JOIN %this.name
          var %this.changeState = 1
        }
      }
      mIRCd.raw %this.sock $+(:,$mIRCd.fulladdr($1)) TOPIC %this.name $+(:,$mIRCd.info(%this.id,topic))
    }
    mIRCd.updateChan %this.id lastActive $ctime
    if (%this.changeState == 1) {
      mIRCd.updateChanUser %this.id $1 0 2
      if ($is_modeSet(%this.id,d).chan == $true) { mIRCd.dCheck %this.id }
    }
    if (%this.flag != $null) { var %this.flag = 0 }
  }
}

; Commands and Functions

alias getChanID {
  ; $getChanID(<#chan>)

  return $hfind($mIRCd.chans,$1,1,W).data
}
alias is_mutual {
  ; $is_mutual(<sockname>,<sockname>)

  var %this.first = $mIRCd.info($1,chans), %this.second = $mIRCd.info($2,chans)
  return $iif($count($regsubex($str(.,$numtok(%this.first,44)),/./g,$iif($istok(%this.second,$gettok(%this.first,\n,44),44) == $true,1,0)),1) > 0,$true,$false)
}
alias is_mutualHidden {
  ; $is_mutualHidden(<sockname using /NICK or /QUIT>,<sockname>)

  var %this.sock = $1
  var %this.first = $mIRCd.info($1,chans), %this.second = $mIRCd.info($2,chans)
  var %this.mutual = $regsubex($str(.,$numtok(%this.first,44)),/./g,$iif($istok(%this.second,$gettok(%this.first,\n,44),44) == $true,$+($gettok(%this.first,\n,44),$comma)))
  return $iif($count($regsubex($str(.,$numtok(%this.mutual,44)),/./g,$gettok($hget($mIRCd.chanUsers($gettok(%this.mutual,\n,44)),%this.sock),2,32)),0) > 0,$false,$true)
}
alias is_on {
  ; $in_on(<chan ID>,<sockname>)

  if ($1 == $null) { return $false }
  return $iif($hget($mIRCd.chanUsers($1),$2) != $null,$true,$false)
}
alias mIRCd.addBan {
  ; /mIRCd.addBan <chan ID> <n!u@h> <setter> <timestamp>

  hadd -m $mIRCd.chanBans($1) $2 $3 $4
}
alias mIRCd.makeAutoJoin {
  ; $mIRCd.makeAutoJoin

  if ($mIRCd(AUTOJOIN_CHANS) == $null) { return }
  var %these.chans = $v1
  var %this.loop = 0
  while (%this.loop < $numtok(%these.chans,44)) {
    inc %this.loop 1
    var %this.target = $gettok($strip($gettok(%these.chans,%this.loop,44)),1,160)
    if ($is_valid(%this.target).chan == $false) { continue }
    if ($len(%this.target) > $mIRCd(MAXCHANNELLEN)) { continue }
    if (($is_klineMatch(%this.target) == $true) || ($is_glineMatch(%this.target) == $true)) { continue }
    var %this.string = $+(%this.target,$comma,%this.string)
    if ($numtok(%this.string,44) >= $hget($mIRCd.targMax,TARGMAX_JOIN)) { break }
    if ($numtok(%this.string,44) >= $mIRCd(MAXCHANNELS)) { break }
  }
  return $sorttok(%this.string,44,a)
}
alias mIRCd.chanAddUser {
  ; /mIRCd.chanAddUser <chan ID> <sockname>

  var %this.id = $1, %this.name = $mIRCd.info(%this.id,name)
  var %this.users = $hcount($mIRCd.chanUsers(%this.id)), %this.opFlag = $iif(%this.users > 0,0,1)
  if (($mIRCd(OPLESS_CHANS) isnum 1-2) && (%this.opFlag == 1)) {
    var %this.opFlag = 0
    if (($mIRCd(OPLESS_CHANS) == 2) && ($is_oper($2) == $true)) { var %this.opFlag = 1 }
  }
  if ((P isincs $mIRCd.info(%this.id,modes)) && ($mIRCd(NOOP_PERSIST) isnum 1-2)) {
    var %this.opFlag = 0
    if (($mIRCd(NOOP_PERSIST) == 2) && ($is_oper($2) == $true)) { var %this.opFlag = 1 }
  }
  hadd -m $mIRCd.chanUsers(%this.id) $2 $ctime $iif(%this.users > 0 && $is_modeSet(%this.id,D).chan == $true,1,0) %this.opFlag 0 0
  ; `-> Explaination of everything here-^: <time joined> <hidden via +D> <op> <hop> <voice>
  mIRCd.updateUser $2 chans $+(%this.id,$comma,$mIRCd.info($2,chans))
  var %this.loop = 0
  while (%this.loop < $hcount($mIRCd.chanUsers(%this.id))) {
    inc %this.loop 1
    var %this.sock = $hget($mIRCd.chanUsers(%this.id),%this.loop).item
    if ($is_modeSet(%this.id,D).chan == $true) {
      if (%this.sock != $2) { continue }
    }
    mIRCd.raw %this.sock $+(:,$mIRCd.fulladdr($2)) JOIN %this.name
  }
  if ($mIRCd.info(%this.id,topic) != $null) {
    ; `-> If a topic exists, send it. It must be sent _BEFORE_ NAMES.
    mIRCd_command_topic $2 TOPIC %this.name
  }
  mIRCd_command_names $2 NAMES %this.name
  ; `-> NOTE: Make sure the user has been added _BEFORE_ invoking NAMES.
  mIRCd.updateChan %this.id lastActive $ctime
}
alias mIRCd.chanDelUser {
  ; /mIRCd.chanDelUser <chan ID> <sockname>

  var %this.id = $1
  hdel $mIRCd.chanUsers(%this.id) $2
  mIRCd.updateChan %this.id lastActive $ctime
  if ($hcount($mIRCd.chanUsers(%this.id)) == 0) {
    ; `-> Destroy the channel because the last user has left. (Unless it's +P, obv.)
    if ($is_modeSet(%this.id,P).chan == $false) { mIRCd.destroyChan %this.id }
  }
  var %this.chans = $remtok($mIRCd.info($2,chans),%this.id,0,44)
  if (%this.chans != $null) {
    mIRCd.updateUser $2 chans %this.chans
    return
  }
  mIRCd.delUserItem $2 chans
}
alias mIRCd.namesStatus {
  ; $mIRCd.namesStatus(<chan ID>,<sockname>)[.top]

  var %this.id = $1, %this.string = $gettok($hget($mIRCd.chanUsers(%this.id),$2),3-,32)
  var %this.return = $regsubex($str(.,$numtok(%this.string,32)),/./g,$iif($gettok(%this.string,\n,32) == 1,$mid(@%+,\n,1)))
  return $iif($prop == top,$left(%this.return,1),%this.return)
}
alias mIRCd.createChan {
  ; /mIRCd.createChan <#chan> <sockname>

  var %this.id = $newChanID
  hadd -m $mIRCd.chans %this.id $1
  hadd -m $mIRCd.table(%this.id) name $1
  hadd -m $mIRCd.table(%this.id) createTime $ctime
  hadd -m $mIRCd.table(%this.id) modes $mIRCd(DEFAULT_CHANMODES).temp
  mIRCd.chanAddUser %this.id $2
}
alias mIRCd.delChanItem {
  ; /mIRCd.delChanItem <chan ID> <item>

  hdel $mIRCd.table($1) $2
}
alias mIRCd.deleteBan {
  ; /mIRCd.deleteBan <chan ID> <n!u@h>

  hdel $mIRCd.chanBans($1) $2
  if ($hcount($mIRCd.chanBans($1)) == 0) { hfree $mIRCd.chanBans($1) }
  ; `-> Free up the empty table.
}
alias mIRCd.destroyChan {
  ; /mIRCd.destroyChan <chan ID>

  var %this.id = $1
  hfree $mIRCd.table(%this.id)
  if ($hget($mIRCd.chanBans(%this.id)) != $null) { hfree $mIRCd.chanBans(%this.id) }
  hfree $mIRCd.chanUsers(%this.id)
  hdel $mIRCd.chans %this.id
  ; `-> Do this one last, on the incredibly rare ocassion that someone tries to /JOIN during destruction.
}
alias mIRCd.updateChan {
  ; /mIRCd.updateUser <chan ID> <item> <value>

  hadd -m $mIRCd.table($1) $2 $3-
}
alias mIRCd.updateChanUser {
  ; /mIRCd.updateChanUser <chan ID> <sockname> <value> <token>

  hadd -m $mIRCd.chanUsers($1) $2 $puttok($hget($mIRCd.chanUsers($1),$2),$3,$4,32)
}
alias newChanID {
  ; $newChanID

  var %this.number = 1
  while ($hget($mIRCd.chans,$+(mIRCd.chan.,%this.number)) != $null) { inc %this.number 1 }
  return $+(mIRCd.chan.,%this.number)
}

; Part Messages

alias mIRCd.joinZero { return Left all channels. (User joined 0.) }
alias mIRCd.standardPart { return Parted }
alias mIRCd.svsPart { return Forced to leave by an IRC operator. }

; EOF
