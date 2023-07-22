; mIRCd_misc.mrc
;
; This script contains the following command(s): AWAY, HELP, ISON, LIST, LUSERS, MKPASSWD, MOTD, PROTOCTL, STATS, USERHOST, USERIP, VERSION,
;   WHOWAS, WHOIS

on *:signal:mIRCd_cleanWhoWas:{ mIRCd.cleanWhoWas }
alias mIRCd_command_away {
  ; /mIRCd_command_away <sockname> AWAY :[away message]

  if (($3 == :) || ($3 == $null)) {
    if ($mIRCd.info($1,away) != $null) { mIRCd.delUserItem $1 away }
    mIRCd.sraw $1 $mIRCd.reply(305,$mIRCd.info($1,nick))
    return
  }
  mIRCd.updateUser $1 away $left($decolonize($3-),$mIRCd(AWAYLEN))
  mIRCd.sraw $1 $mIRCd.reply(306,$mIRCd.info($1,nick))
}
alias mIRCd_command_help {
  ; /mIRCd_command_help <sockname> HELP [item]

  if ($3 == $null) {
    var %this.sock = $1
    tokenize 44 $remtok($sorttok($left($regsubex($str(.,$hget($mIRCd.commands(1),0).data),/./g,$+($hget($mIRCd.commands(1),\n).data,$comma)),-1),44),PROTOCTL,1,44)
    scon -r mIRCd.sraw %this.sock NOTICE $mIRCd.info(%this.sock,nick) $!+(:, $* )
    ; `-> A quick and dirty loop.
    return
  }
  var %this.file = $+($mIRCd.dirHelp,$3,.help")
  if ($lines(%this.file) == 0) {
    mIRCd.sraw $1 $mIRCd.reply(608,$mIRCd.info($1,nick),$3)
    return
  }
  var %this.loop = 0
  while (%this.loop < $lines(%this.file)) {
    inc %this.loop 1
    mIRCd.sraw $1 $mIRCd.reply(610,$mIRCd.info($1,nick),$3,$replace($read(%this.file, n, %this.loop), <helpCommand>, $upper($2), <thisCommand>, $upper($3), <thisNetwork>, $mIRCd(NETWORK_NAME), <thisName>, $mIRCd.info($1,realName), <thisNick>, $mIRCd.info($1,nick), <thisUser>, $remove($mIRCd.info($1,user), ~)))
  }
  mIRCd.sraw $1 $mIRCd.reply(611,$mIRCd.info($1,nick),$3)
}
alias mIRCd_command_ison {
  ; /mIRCd_command_ison <sockname> ISON <nick [nick nick ...]>

  if ($3 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.isons = $3-
  if ($hget($mIRCd.targMax,TARGMAX_ISON) isnum 1-) { var %this.isons = $deltok(%this.isons,$+($calc($v1 + 1),-),32) }
  if (%this.isons == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.loop = 0, %this.string = $null
  while (%this.loop < $numtok(%this.isons,32)) {
    inc %this.loop 1
    var %this.nick = $gettok(%this.isons,%this.loop,32)
    if ($getSockname(%this.nick) != $null) { var %this.string = %this.string $mIRCd.info($getSockname(%this.nick),nick) }
    ; `-> NOTE: This has to return their EXACT nick.
    if ($len(%this.string) > 500) { return }
    ; `-> NOTE: The length of an ison reply is limited to 512(?) characters. But, we'll use 500 as a failsafe.
  }
  mIRCd.sraw $1 $mIRCd.reply(303,$mIRCd.info($1,nick),%this.string)
}
alias mIRCd_command_list {
  ; /mIRCd_command_list <sockname> LIST [term[,term,term,...]|STOP]

  if ($mIRCd(CONNECTED_LIST_THROTTLE) isnum 1-) {
    if (($sock($1).to <= $mIRCd(CONNECTED_LIST_THROTTLE)) && ($is_oper($1) == $false)) {
      mIRCd.sraw $1 NOTICE $mIRCd.info($1,nick) $+(:/,$upper($2)) cannot be used for $mIRCd(CONNECTED_LIST_THROTTLE) second(s) upon connecting to the server.
      return
    }
  }
  if ($3 == STOP) {
    if ($mIRCd.info($1,listing) != $null) {
      mIRCd.delUserItem $1 listing
      mIRCd.sraw $1 NOTICE $mIRCd.info($1,nick) $+(:/,$upper($2)) aborted
      goto exitSafely
    }
    return
  }
  if ($mIRCd.info($1,listing) == $null) {
    ; `-> WARNING!: _DO NOT_ allow /LIST on top of /LIST!
    mIRCd.updateUser $1 listing 1
    mIRCd.sraw $1 $mIRCd.reply(321,$mIRCd.info($1,nick))
    var %this.loop = 0
    while (%this.loop < $hcount($mIRCd.chans)) {
      var %this.skipList = 0, %this.onChan = 0, %this.modes = $null, %this.modeArgs = $null, %this.string = $null
      inc %this.loop 1
      if ($mIRCd.info($1,listing) == $null) { break }
      ; `-> Backup. If listing was removed via STOP, stop listing.
      var %this.id = $hget($mIRCd.chans,%this.loop).item
      if (($3 != $null) && ($3 != STOP)) {
        var %this.searchLoop = 0
        while (%this.searchLoop < $numtok($3,44)) {
          inc %this.searchLoop 1
          var %this.term = $gettok($3,%this.searchLoop,44)
          if ($regex(%this.term,^(=|>|<|>=|<|<=|!=)\d+) == 1) {
            ; `-> Users.
            var %this.cmp = $_stripNumbers(%this.term), %this.match = $_stripMatch(%this.term)
            var %this.result = $iif($hcount($mIRCd.chanUsers(%this.id)) %this.cmp %this.match,1,0)
            if (%this.result == 0) {
              var %this.skipList = 1
              break
            }
          }
          if ($regex(%this.term,^C(=|>|<|>=|<|<=|!=)\d+) == 1) {
            ; `-> Creation.
            var %this.cmp = $remove($_stripNumbers(%this.term), C), %this.match = $remove($_stripMatch(%this.term), C)
            var %this.result = $iif($calc($ctime - $mIRCd.info(%this.id,createTime)) %this.cmp $calc(%this.match * 60),1,0)
            if (%this.result == 0) {
              var %this.skipList = 1
              break
            }
          }
          if ($regex(%this.term,^M(=|>|<|>=|<|<=|!=)\d+) == 1) {
            ;   `-> Activity.
            var %this.cmp = $remove($_stripNumbers(%this.term), M), %this.match = $remove($_stripMatch(%this.term), M)
            var %this.result = $iif($calc($ctime - $mIRCd.info(%this.id,lastActive)) %this.cmp $calc(%this.match * 60),1,0)
            if (%this.result == 0) {
              var %this.skipList = 1
              break
            }
          }
          if ($regex(%this.term,^T(=|>|<|>=|<|<=|!=)\d+) == 1) {
            ; `-> Topic.
            var %this.cmp = $remove($_stripNumbers(%this.term), T), %this.match = $remove($_stripMatch(%this.term), T)
            if ($mIRCd.info(%this.id,topicTime) == $null) {
              var %this.skipList = 1
              break
            }
            var %this.result = $iif($calc($ctime - $mIRCd.info(%this.id,topicTime)) %this.cmp $calc(%this.match * 60),1,0)
            if (%this.result == 0) {
              var %this.skipList = 1
              break
            }
          }
          if (($left(%this.term,1) == !) && ($left(%this.term,2) != !=)) {
            ; `-> !not matching pattern. E.g. Filter out everything containing !*twitter*
            if (($mIRCd.info(%this.id,name) == $right(%this.term,-1)) || ($right(%this.term,-1) iswm $mIRCd.info(%this.id,name))) {
              var %this.skipList = 1
              break
            }
          }
          if ($istok(! < = > C M T,$left(%this.term,1),32) == $false) {
            ; ,-> Matching pattern.
            if (($mIRCd.info(%this.id,name) != %this.term) && (%this.term !iswm $mIRCd.info(%this.id,name))) {
              var %this.skipList = 1
              break
            }
          }
        }
        if (%this.skipList == 1) { continue }
      }
      if (($is_oper($1) == $true) || ($is_on(%this.id,$1) == $true)) { var %this.onChan = 1 }
      if (($is_private(%this.id) == $true) || ($is_secret(%this.id) == $true)) {
        if (%this.OnChan != 1) { continue }
      }
      var %this.modes = $mIRCd.info(%this.id,modes), %this.modeItem = B bandwidth,g gagTime,j joinThrottle,l limit,k key
      var %this.key = $iif(%this.onChan == 1,$mIRCd.info(%this.id,key),*)
      ; `-> Key needs to appear as * if they're not an oper or not on the channel.
      var %this.modeArgs = $regsubex(%this.modes,/(.)/g,$iif($poscs(Bgjlk,\t) != $null,$+($iif(\t === k,%this.key,$mIRCd.info(%this.id,$gettok($matchtokcs(%this.modeItem,$+(\t,$chr(32)),1,44),2,32))),$chr(32))))
      var %this.modeString = $bracket(%this.modes $iif(%this.ModeArgs != $null,$v1))
      if (H isincs %this.modes) {
        if (%this.onChan != 1) { var %this.modeString = $null }
      }
      var %this.string = %this.modeString $mIRCd.info(%this.id,topic)
      mIRCd.sraw $1 $mIRCd.reply(322,$mIRCd.info($1,nick),$mIRCd.info(%this.id,name),$hcount($mIRCd.chanUsers(%this.id)),%this.string)
    }
  }
  :exitSafely
  mIRCd.sraw $1 $mIRCd.reply(323,$mIRCd.info($1,nick))
  if ($mIRCd.info($1,listing) != $null) { mIRCd.delUserItem $1 listing }
}
alias mIRCd_command_lusers {
  ; /mIRCd_command_lusers <sockname> LUSERS

  mIRCd.sraw $1 $mIRCd.reply(251,$mIRCd.info($1,nick))
  mIRCd.sraw $1 $mIRCd.reply(252,$mIRCd.info($1,nick))
  if ($hcount($mIRCd.unknown) > 0) { mIRCd.sraw $1 $mIRCd.reply(253,$mIRCd.info($1,nick)) }
  mIRCd.sraw $1 $mIRCd.reply(254,$mIRCd.info($1,nick))
  mIRCd.sraw $1 $mIRCd.reply(255,$mIRCd.info($1,nick))
  mIRCd.sraw $1 $mIRCd.reply(265,$mIRCd.info($1,nick),$mIRCd(highCount).temp)
  ; PLACEHOLDER FOR NUMERIC 266: GLOBAL_INFO/GLOBAL_MAX
  ; ,-> WARNING!: If you change the line for raw 250 in mIRCd.raws it will totally screw up the line below. So, either don't change the line, or comment the two lines below out after you change it.
  var %this.string = $hget($mIRCd.raws,250)
  mIRCd.sraw $1 NOTICE $mIRCd.info($1,nick) $puttok($puttok(%this.string,$mIRCd(highCount).temp,4,32),$+($chr(40),$mIRCd(highCount).temp),5,32) $parenthesis($mIRCd(totalCount).temp connection(s) received)
}
alias mIRCd_command_mkpasswd {
  ; /mIRCd_command_mkpasswd <sockname> MKPASSWD <password>

  if ($3 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  mIRCd.sraw $1 NOTICE $mIRCd.info($1,nick) :Encrypted: $mIRCd.encryptPass($3)
}
alias mIRCd_command_motd {
  ; /mIRCd_command_motd <sockname> MOTD

  if ($lines($mIRCd.fileMotd) == 0) {
    mIRCd.sraw $1 $mIRCd.reply(422,$mIRCd.info($1,nick))
    return
  }
  mIRCd.sraw $1 $mIRCd.reply(375,$mIRCd.info($1,nick))
  mIRCd.sraw $1 $mIRCd.reply(372,$mIRCd.info($1,nick),$asctime($file($mIRCd.fileMotd).mtime,dd/mm/yyyy HH:nn))
  ; `-> I believe this line showing the last time that the MOTD was updated is in fact entirely optional. (No harm in having it, though.)
  var %this.loop = 0
  while (%this.loop < $lines($mIRCd.fileMotd)) {
    inc %this.loop 1
    mIRCd.sraw $1 $mIRCd.reply(372,$mIRCd.info($1,nick),$read($mIRCd.fileMotd, n, %this.loop))
  }
  mIRCd.sraw $1 $mIRCd.reply(376,$mIRCd.info($1,nick))
}
alias mIRCd_command_protoctl {
  ; /mIRCd_command_protoctl <sockname> PROTOCTL <uhnames|namesx> [boolean value]
  ;
  ; [boolean value] isn't part of the protocol, but I've adapted it here for flexibility.

  if ($3 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.bool =  $iif($4 != $null,$iif($bool_fmt($4) == $true,1,0),1)
  if ($3 == NAMESX) {
    mIRCd.updateUser $1 NAMESX %this.bool
    return
  }
  if ($3 == UHNAMES) {
    mIRCd.updateUser $1 UHNAMES %this.bool
    return
  }
}
; ¦-> If the client does these, it means they want NAMESX (@%+nick) and UHNAMES (n!u@h) in /NAMES replies.
; `-> mIRCd now takes this into consideration. They can update these at any time. (Defaults to TRUE.)
alias mIRCd_command_stats {
  ; /mIRCd_command_stats <sockname> STATS <flag>

  if ($3 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  if ($mIRCd(OPER_STATS) != $null) {
    if (($istokcs($mIRCd(OPER_STATS),$3,44) == $true) && ($is_oper($1) == $false)) {
      mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick))
      return
    }
  }
  ; ,-> I honestly doubt anything else other than these few will be added?
  if ($poscs(gkmopsuzGKMOPSUZ,$3) == $null) {
    ; ,-> Just return "End of /STATS report" regardless of if it exists or not.
    mIRCd.sraw $1 $mIRCd.reply(219,$mIRCd.info($1,nick),$3)
    return
  }
  if ($3 == g) {
    ; `-> g/G are the same.
    var %this.loop = 0
    while (%this.loop < $hcount($mIRCd.glines)) {
      inc %this.loop 1
      var %this.item = $hget($mIRCd.glines,%this.loop).item
      var %this.data = $hget($mIRCd.glines,%this.item)
      mIRCd.sraw $1 $mIRCd.reply(247,$mIRCd.info($1,nick),%this.item,$left($gettok(%this.data,1,32),-1),$gettok(%this.data,2-,32))
    }
    mIRCd.sraw $1 $mIRCd.reply(219,$mIRCd.info($1,nick),$3)
    return
  }
  if ($3 == k) {
    ; `-> Ditto.
    var %this.loop = 0
    while (%this.loop < $hcount($mIRCd.klines)) {
      inc %this.loop 1
      var %this.item = $hget($mIRCd.klines,%this.loop).item
      mIRCd.sraw $1 $mIRCd.reply(216,$mIRCd.info($1,nick),%this.item,$hget($mIRCd.klines,%this.item))
    }
    mIRCd.sraw $1 $mIRCd.reply(219,$mIRCd.info($1,nick),$3)
    return
  }
  if ($3 == m) {
    ; `-> Ditto.
    var %this.loop = 0
    while (%this.loop < $hget($mIRCd.commands(1),0).data) {
      inc %this.loop 1
      var %this.command = $hget($mIRCd.commands(1),%this.loop).data, %this.data = $iif($hget($mIRCd.mStats,%this.command) != $null,$v1,0)
      if ($gettok(%this.data,1,32) == 0) { continue }
      mIRCd.sraw $1 $mIRCd.reply(212,$mIRCd.info($1,nick),%this.command,%this.data)
    }
    mIRCd.sraw $1 $mIRCd.reply(219,$mIRCd.info($1,nick),$3)
    return
  }
  if ($3 == o) {
    ; `-> Ditto for o/O.
    var %this.loop = 0
    while (%this.loop < $hcount($mIRCd.opers)) {
      inc %this.loop 1
      var %this.item = $hget($mIRCd.opers,%this.loop).item
      mIRCd.sraw $1 $mIRCd.reply(243,$mIRCd.info($1,nick),%this.item)
    }
    mIRCd.sraw $1 $mIRCd.reply(219,$mIRCd.info($1,nick),$3)
    return
  }
  if ($3 == p) {
    ; `-> Ditto for p/P.
    var %this.sock = $1, %this.flag = $3
    tokenize 44 $sorttok($mIRCd(CLIENT_PORTS),44,n)
    scon -r mIRCd.sraw %this.sock $!mIRCd.reply(217,$mIRCd.info(%this.sock,nick),%this.flag, $* )
    ; ¦-> A quick and dirty loop.
    ; `-> I also believe the final * on the raw reply - which should actually be a number here - is the amount of clients on that port?
    mIRCd.sraw %this.sock $mIRCd.reply(219,$mIRCd.info(%this.sock,nick),%this.flag)
    return
  }
  if ($3 === s) {
    ; `-> Note: This _MUST_ now be lowercase.
    var %this.loop = 0
    while (%this.loop < $hcount($mIRCd.shuns)) {
      inc %this.loop 1
      var %this.item = $hget($mIRCd.shuns,%this.loop).item
      var %this.data = $hget($mIRCd.shuns,%this.item)
      mIRCd.sraw $1 $mIRCd.reply(290,$mIRCd.info($1,nick),%this.item,$left($gettok(%this.data,1,32),-1),$gettok(%this.data,2-,32))
    }
    if ($hcount($mIRCd.local(Shuns)) == 0) {
      mIRCd.sraw $1 $mIRCd.reply(219,$mIRCd.info($1,nick),$3)
      return
    }
    var %this.loop = 0
    while (%this.loop < $hcount($mIRCd.local(Shuns))) {
      inc %this.loop 1
      var %this.item = $hget($mIRCd.local(Shuns),%this.loop).item
      mIRCd.sraw $1 $mIRCd.reply(290,$mIRCd.info($1,nick),%this.item,N/A,$hget($mIRCd.local(Shuns),%this.item))
    }
    mIRCd.sraw $1 $mIRCd.reply(219,$mIRCd.info($1,nick),$3)
    return
  }
  if ($3 === S) {
    ; `-> _Uppercase_!
    var %this.loop 0
    while (%this.loop < $hcount($mIRCd.slines)) {
      inc %this.loop 1
      mIRCd.sraw $1 $mIRCd.reply(229,$mIRCd.info($1,nick),$hget($mIRCd.slines,%this.loop).item)
    }
    mIRCd.sraw $1 $mIRCd.reply(219,$mIRCd.info($1,nick),$3)
    return
  }
  if ($3 === u) {
    ; `-> Note: This _MUST_ be lowercase.
    var %this.duration = $calc($ctime - $iif($mIRCd(startTime).temp != $null,$v1,$sock($mIRCd.info($1,thruSock)).to))
    var %this.days = $int($calc(%this.duration / 86400)), %this.hours = $int($calc((%this.duration % 86400) / 3600))
    var %this.mins = $int($calc((%this.duration % 3600) / 60)), %this.secs = $int($calc(%this.duration % 60))
    var %this.output = %this.days days, $+(%this.hours,:,$base(%this.mins,10,10,2),:,$base(%this.secs,10,10,2))
    mIRCd.sraw $1 $mIRCd.reply(242,$mIRCd.info($1,nick),%this.output)
    mIRCd.sraw $1 $mIRCd.reply(250,$mIRCd.info($1,nick),$mIRCd(highCount).temp,$mIRCd(highCount).temp)
    mIRCd.sraw $1 $mIRCd.reply(219,$mIRCd.info($1,nick),$3)
    return
  }
  if ($3 === U) {
    ; `-> _Uppercase_!
    if ($hcount($mIRCd.badNicks) > 0) {
      var %this.string = $sorttok($left($regsubex($str(.,$hget($mIRCd.badNicks,0).item),/./g,$+($hget($mIRCd.badNicks,\n).data,$comma)),-1),44,a)
      mIRCd.sraw $1 $mIRCd.reply(248,$mIRCd.info($1,nick),%this.string)
    }
    mIRCd.sraw $1 $mIRCd.reply(219,$mIRCd.info($1,nick),$3)
    return
  }
  if ($3 == z) {
    ; `-> Ditto for z/Z.
    var %this.loop = 0
    while (%this.loop < $hcount($mIRCd.zlines)) {
      inc %this.loop 1
      var %this.item = $hget($mIRCd.zlines,%this.loop).item
      var %this.data = $hget($mIRCd.zlines,%this.item)
      mIRCd.sraw $1 $mIRCd.reply(292,$mIRCd.info($1,nick),%this.item,$left($gettok(%this.data,1,32),-1),$gettok(%this.data,2-,32))
    }
    if ($hcount($mIRCd.local(Zlines)) == 0) {
      mIRCd.sraw $1 $mIRCd.reply(219,$mIRCd.info($1,nick),$3)
      return
    }
    var %this.loop = 0
    while (%this.loop < $hcount($mIRCd.local(Zlines))) {
      inc %this.loop 1
      var %this.item = $hget($mIRCd.local(Zlines),%this.loop).item
      mIRCd.sraw $1 $mIRCd.reply(292,$mIRCd.info($1,nick),%this.item,N/A,$hget($mIRCd.local(Zlines),%this.item))
    }
    mIRCd.sraw $1 $mIRCd.reply(219,$mIRCd.info($1,nick),$3)
    return
  }
}
alias mIRCd_command_userhost {
  ; /mIRCd_command_userhost <sockname> USERHOST <nick [nick nick ...]>

  if ($3 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.userhosts = $3-
  if ($hget($mIRCd.targMax,TARGMAX_USERHOST) isnum 1-) { var %this.userhosts = $deltok(%this.userhosts,$+($calc($v1 + 1),-),32) }
  if (%this.userhosts == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.loop = 0, %this.string = $null
  while (%this.loop < $numtok(%this.userhosts,32)) {
    inc %this.loop 1
    var %this.nick = $gettok(%this.userhosts,%this.loop,32)
    if ($getSockname(%this.nick) != $null) {
      var %this.sock = $v1
      var %this.operFlag = $iif($is_oper(%this.sock) == $true,*), %this.host = $iif($is_modeSet(%this.sock,x).nick == $true && $bool_fmt($mIRCd(HIDE_HOSTS_FREELY)) == $true && $is_oper($1) == $false,$mIRCd.info(%this.sock,host),$mIRCd.info(%this.sock,trueHost))
      var %this.string = %this.string $+(%this.nick,%this.operFlag,=,$iif($mIRCd.info(%this.sock,away) != $null,-,+),$iif($mIRCd.info(%this.sock,ident) != $null,$v1,$mIRCd.info(%this.sock,user)),@,%this.host)
    }
    if ($numtok(%this.string,32) == 5) { break }
    ; `-> This command is limited to five replies.
  }
  mIRCd.sraw $1 $mIRCd.reply(302,$mIRCd.info($1,nick),%this.string)
}
alias mIRCd_command_userip {
  ; /mIRCd_command_userip <sockname> USERIP <nick [nick nick ...]>

  if ($3 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.userips = $3-
  if ($hget($mIRCd.targMax,TARGMAX_USERIP) isnum 1-) { var %this.userips = $deltok(%this.userips,$+($calc($v1 + 1),-),32) }
  if (%this.userips == $null) {
    mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.loop = 0, %this.string = $null
  while (%this.loop < $numtok(%this.userips,32)) {
    inc %this.loop 1
    var %this.nick = $gettok(%this.userips,%this.loop,32)
    if ($getSockname(%this.nick) != $null) {
      var %this.sock = $v1
      var %this.operFlag = $iif($is_oper(%this.sock) == $true,*), %this.ip = $iif($is_modeSet(%this.sock,x).nick == $true && $bool_fmt($mIRCd(HIDE_HOSTS_FREELY)) == $true && $is_oper($1) == $false,$mIRCd.fakeIP,$sock(%this.sock).ip)
      var %this.string = %this.string $+(%this.nick,%this.operFlag,=,$iif($mIRCd.info(%this.sock,away) != $null,-,+),$iif($mIRCd.info(%this.sock,ident) != $null,$v1,$mIRCd.info(%this.sock,user)),@,%this.ip)
    }
    if ($numtok(%this.string,32) == 5) { break }
    ; `-> This command is limited to five replies.
  }
  mIRCd.sraw $1 $mIRCd.reply(340,$mIRCd.info($1,nick),%this.string)
}
alias mIRCd_command_version {
  ; /mIRCd_command_version <sockname> VERSION

  mIRCd.sraw $1 $mIRCd.reply(351,$mIRCd.info($1,nick))
  mIRCd.raw005 $1
}
alias mIRCd_command_whois {
  ; /mIRCd_command_whois <sockname> WHOIS <nick[,nick,nick,...]>

  if ($3 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(431,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.whois = $3
  if ($hget($mIRCd.targMax,TARGMAX_WHOIS) isnum 1-) { var %this.whois = $deltok(%this.whois,$+($calc($v1 + 1),-),44) }
  if (%this.whois == $null) {
    mIRCd.sraw $1 $mIRCd.reply(431,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.loop = 0
  while (%this.loop < $numtok(%this.whois,44)) {
    inc %this.loop 1
    var %this.nick = $gettok(%this.whois,%this.loop,44), %this.sock = $getSockname(%this.nick)
    if (* isin %this.nick) {
      mIRCd.sraw $1 $mIRCd.reply(416,$mIRCd.info($1,nick),%this.nick)
      continue
    }
    if ($is_exists(%this.nick).nick == $false) {
      mIRCd.sraw $1 $mIRCd.reply(401,$mIRCd.info($1,nick),%this.nick)
      continue
    }
    var %this.nick = $mIRCd.info(%this.sock,nick)
    ; `-> Use their properly formatted nick.
    if (($is_modeSet(%this.sock,W).nick == $true) && ($1 != %this.sock)) { mIRCd.sraw %this.sock NOTICE %this.nick $+(:,$mIRCd.info($1,nick)) is performing a $+(/,$upper($2)) on you. }
    var %this.user = $iif($mIRCd.info(%this.sock,ident) != $null,$v1,$mIRCd.info(%this.sock,user))
    mIRCd.sraw $1 $mIRCd.reply(311,$mIRCd.info($1,nick),%this.nick,%this.user,$mIRCd.info(%this.sock,host),$mIRCd.info(%this.sock,realName))
    var %this.chans = $mIRCd.info(%this.sock,chans)
    ; `-> Note: +k (Network Service) should skip sending channels as well; but that's only for services connected via a C:lined server.
    if (%this.chans != $null) {
      if ($is_modeSet(%this.sock,d).nick == $true) { var %this.flag = - }
      var %this.chan = 0, %this.string = $null
      while (%this.chan < $numtok(%this.chans,44)) {
        inc %this.chan 1
        var %this.id = $gettok(%this.chans,%this.chan,44)
        var %this.status = $mid(@%+,$findtok($gettok($hget($mIRCd.chanUsers(%this.id),%this.sock),3-,32),1,1,32),1)
        if ($is_modeSet(%this.sock,n).nick == $true) {
          if (($is_oper($1) == $true) || ($1 == %this.sock)) { goto processWhois }
          goto cleanupString
        }
        if ($is_modeSet(%this.sock,i).nick == $true) {
          if (($is_oper($1) == $true) || ($1 == %this.sock) || ($is_mutualID(%this.id,$1,%this.sock) == $true)) { goto processWhois }
          goto cleanupString
        }
        if ($is_private(%this.id) == $true) {
          if ($is_oper($1) == $true) || ($1 == %this.sock) || ($is_mutualID(%this.id,$1,%this.sock) == $true)) { goto processWhois }
          goto cleanupString
        }
        if ($is_secret(%this.id) == $true) {
          if (($is_oper($1) == $true) || ($1 == %this.sock) || ($is_mutualID(%this.id,$1,%this.sock) == $true)) { goto processWhois }
          goto cleanupString
        }
        :processWhois
        var %this.string = %this.string $+(%this.flag,%this.status,$mIRCd.info(%this.id,name))
        :cleanupString
        if ($len(%this.string) >= 399) {
          ; `-> If the length of the string is longer than or equal to 399 characters (#becauseofusersjoiningtotallylongasschannelnames) send the string.
          mIRCd.sraw $1 $mIRCd.reply(319,$mIRCd.info($1,nick),%this.nick,%this.string)
          var %this.string = $null
        }
      }
      if (%this.string != $null) { mIRCd.sraw $1 $mIRCd.reply(319,$mIRCd.info($1,nick),%this.nick,%this.string) }
    }
    if (($is_oper($1) == $true) || ($1 == %this.sock)) { mIRCd.sraw $1 $mIRCd.reply(338,$mIRCd.info($1,nick),%this.nick,$+(%this.user,@,$mIRCd.info(%this.sock,trueHost)),$sock(%this.sock).ip) }
    mIRCd.sraw $1 $mIRCd.reply(312,$mIRCd.info($1,nick),%this.nick,$mIRCd(SERVER_NAME).temp,$mIRCd(NETWORK_INFO))
    if ($is_modeSet(%this.sock,o).nick == $true) { mIRCd.sraw $1 $mIRCd.reply(313,$mIRCd.info($1,nick),%this.nick) }
    if ($is_modeSet(%this.sock,k).nick == $true) { mIRCd.sraw $1 $mIRCd.reply(310,$mIRCd.info($1,nick),%this.nick) }
    if ($is_modeSet(%this.sock,D).nick == $true) { mIRCd.sraw $1 $mIRCd.reply(316,$mIRCd.info($1,nick),%this.nick) }
    if ($is_modeSet(%this.sock,B).nick == $true) { mIRCd.sraw $1 $mIRCd.reply(336,$mIRCd.info($1,nick),%this.nick) }
    if ($mIRCd.info(%this.sock,away) != $null) { mIRCd.sraw $1 $mIRCd.reply(301,$mIRCd.info($1,nick),%this.nick,$v1) }
    if ($is_modeSet(%this.sock,I).nick == $true) {
      if (($is_oper($1) != $true) || ($1 != %this.sock)) { goto skipIdle }
    }
    mIRCd.sraw $1 $mIRCd.reply(317,$mIRCd.info($1,nick),%this.nick,$iif($mIRCd.info(%this.sock,idleTime) != $null,$calc($ctime - $v1),$sock(%this.sock).to),$calc($ctime - $sock(%this.sock).to))
    :skipIdle
  }
  mIRCd.sraw $1 $mIRCd.reply(318,$mIRCd.info($1,nick),$3)
}
alias mIRCd_command_whowas {
  ; /mIRCd_command_whowas <sockname> WHOWAS <nick[,nick,nick,...]>

  if ($3 == $null) {
    mIRCd.sraw $1 $mIRCd.reply(431,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.whowas = $3
  if ($hget($mIRCd.targMax,TARGMAX_WHOWAS) isnum 1-) { var %this.whowas = $deltok(%this.whowas,$+($calc($v1 + 1),-),44) }
  if (%this.whowas == $null) {
    mIRCd.sraw $1 $mIRCd.reply(431,$mIRCd.info($1,nick),$2)
    return
  }
  var %this.loop = 0
  while (%this.loop < $numtok(%this.whowas,44)) {
    inc %this.loop 1
    var %this.nick = $gettok(%this.whowas,%this.loop,44)
    if (* isin %this.nick) {
      mIRCd.sraw $1 $mIRCd.reply(406,$mIRCd.info($1,nick),%this.nick)
      continue
    }
    if ($is_whoWasMatch(%this.nick) == $false) {
      mIRCd.sraw $1 $mIRCd.reply(406,$mIRCd.info($1,nick),%this.nick)
      continue
    }
    var %this.wasLoop = 0
    while (%this.wasLoop < $hfind($mIRCd.whoWas,$+(%this.nick,:,*),0,w)) {
      inc %this.wasLoop 1
      var %this.table = $hfind($mIRCd.whoWas,$+(%this.nick,:,*),%this.wasLoop,w).item
      var %this.user = $iif($hget($mIRCd.whoWas(%this.table),ident) != $null,$v1,$hget($mIRCd.whoWas(%this.table),user)), %this.host = $hget($mIRCd.whoWas(%this.table),$iif($is_oper($1) == $true,trueHost,host))
      ; `-> Only oper(s) can see the trueHost.
      mIRCd.sraw $1 $mIRCd.reply(314,$mIRCd.info($1,nick),$hget($mIRCd.whoWas(%this.table),nick),%this.user,%this.host,$hget($mIRCd.whoWas(%this.table),realName))
      mIRCd.sraw $1 $mIRCd.reply(312,$mIRCd.info($1,nick),$hget($mIRCd.whoWas(%this.table),nick),$mIRCd(SERVER_NAME).temp,$asctime($hget($mIRCd.whoWas(%this.table),signon),ddd mmm d hh:mm:ss yyyy))
    }
  }
  mIRCd.sraw $1 $mIRCd.reply(369,$mIRCd.info($1,nick),%this.whowas)
}

; Commands and Functions

alias is_mutualID {
  ; $is_mutualID(<chan ID>,<sockname>,<sockname>)

  var %this.first = $iif($hget($mIRCd.chanUsers($1),$2) != $null,1,0), %this.second = $iif($hget($mIRCd.chanUsers($1),$3) != $null,1,0)
  return $iif($calc(%this.first + %this.second) == 2,$true,$false)
}
alias is_whoWasMatch {
  ; $is_whoWasMatch(<nick>)

  return $iif($hfind($mIRCd.whoWas,$+($1,:,*),0,w) > 0,$true,$false)
}
; `-> Redundant?
alias mIRCd.cleanWhoWas {
  ; /mIRCd.cleanWhoWas

  if ($hcount($mIRCd.whoWas) == 0) { return }
  if ($mIRCd(CLEAR_WHOWAS_CACHE) != $null) {
    var %this.temp = $v1
    if (%this.temp !isnum 1-) {
      var %this.duration = 86400
      goto clearEntries
    }
    var %this.duration = %this.temp
    goto clearEntries
  }
  var %this.duration = 86400
  ; `-> 86400s is 1d.
  :clearEntries
  var %this.loop = $hcount($mIRCd.whoWas)
  while (%this.loop > 0) {
    var %this.table = $hget($mIRCd.whoWas,%this.loop).item
    if ($calc($ctime - $gettok(%this.table,2,58)) >= %this.duration) {
      hfree $mIRCd.whoWas(%this.table)
      hdel $mIRCd.whoWas %this.table
    }
    dec %this.loop 1
  }
}
alias mIRCd.dirHelp { return $+(",$scriptdirconf\help\) }
; `-> Note: The closing quote is missing because of what'll be done in the command.
alias mIRCd.encryptPass { return $hmac($sha512($1), $+($1,:,$mIRCd(SALT).temp), sha512, 0) }
alias mIRCd.fileMotd { return $+($scriptdirmIRCd.motd) }
alias mIRCd.mkpasswd {
  ; /mIRCd.mkpasswd <password>

  if ($1 == $null) {
    mIRCd.echo /mIRCd.mkpasswd: insufficient parameters
    return
  }
  clipboard $mIRCd.encryptPass($1)
  mIRCd.echo /mIRCd.mkpasswd: copied password to clipboard
}
; `-> For generating "O:lines." (Oper password.)

; EOF
