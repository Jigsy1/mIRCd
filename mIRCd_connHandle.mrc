; mIRCd_connHandle.mrc
;
; This is for processing connections only.

on *:dns:{
  var %this.dns = 0
  while (%this.dns < $dns(0)) {
    inc %this.dns 1
    if ($hfind($mIRCd.dns,$dns(%this.dns),1,W).data != $null) {
      var %this.result = $v1
      mIRCd.sraw $v1 NOTICE $mIRCd.info($v1,nick) :*** Found your hostname
      mIRCd.updateUser $v1 host $dns(%this.dns).addr
      mIRCd.updateUser $v1 trueHost $dns(%this.dns).addr
      if ($hget($mIRCd.dns,%this.result) != $null) { hdel $mIRCd.dns %this.result }
    }
  }
  haltdef
}
on *:sockclose:mIRCd.*:{
  if (mIRCd.ident.* iswm $sockname) {
    mIRCd.destroyIdent $sockname
    return
  }
  ; >-> Placeholder for anything server related in the future.
  if (mIRCd.user.* iswm $sockname) {
    mIRCd.errorUser $sockname $mIRCd.socketClosed
    return
  }
}
on *:socklisten:mIRCd.*:{
  var %this.port = $gettok($sockname,2,46)
  if ($istok($mIRCd(CLIENT_PORTS),%this.port,44) == $true) {
    var %this.number = 1, %this.type = mIRCd.user.
    while ($sock($+(%this.type,%this.number)) != $null) { inc %this.number 1 }
    mIRCd.createUser $+(%this.type,%this.number) $sockname
    return
  }
  ; `-> Placeholder for anything server related in the future.
}
on *:sockopen:mIRCd.ident.*:{
  if ($sockerr == 0) { sockwrite -nt $sockname $hget($mIRCd.ident,$sockname) }
}
on *:sockread:mIRCd.*:{
  if (mIRCd.ident.* iswm $sockname) {
    var %mIRCd.ident.sockRead = $null
    sockread %mIRCd.ident.sockRead
    tokenize 32 %mIRCd.ident.sockRead
    if ($sockerr > 0) {
      mIRCd.destroyIdent $sockname
      return
    }
    tokenize 58 $3-
    if ($3 != $null) { mIRCd.updateUser $+(mIRCd.user.,$gettok($sockname,-1,46)) ident $left($3,$mIRCd.userLen) }
    mIRCd.destroyIdent $sockname
    return
  }
  ; >-> Placeholder for anything server related in the future.
  if (mIRCd.user.* iswm $sockname) {
    var %mIRCd.user.sockRead = $null
    sockread %mIRCd.user.sockRead
    tokenize 32 %mIRCd.user.sockRead

    if ($window($mIRCd.window) != $null) { echo -ci2t "Info text" $v1 [R]: $sockname -> $1- }
    if ($sockerr > 0) {
      mIRCd.errorUser $sockname $mIRCd.socketError
      return
    }
    if ($mIRCd.info($sockname,isReg) == 0) {
      ; `-> Unregistered.
      if ($istok($mIRCd.commands(0),$1,44) == $true) {
        mIRCd.doCommand $sockname $1-
        return
      }
      mIRCd.sraw $sockname $mIRCd.reply(451,$iif($mIRCd.info($sockname,nick) != $null,$v1,*),$1)
      return
    }
    ; `-> Registered.
    if (($is_shunMatch($mIRCd.fulladdr($sockname)) == $true) || ($is_shunMatch($mIRCd.trueaddr($sockname)) == $true)) {
      if ($istok($mIRCd.commands(2),$1,44) == $true) {
        mIRCd.doCommand $sockname $1-
        return
      }
      if ($istok($mIRCd.commands(1),$1,44) == $false) { mIRCd.sraw $sockname $mIRCd.reply(421,$mIRCd.info($sockname,nick),$1) }
      ; `-> Tell them failed commands don't work, but ignore everything else they try to do.
      return
    }
    if ($istok($mIRCd.commands(1),$1,44) == $true) {
      if (($istok($mIRCd(OPER_CMDS),$1,44) == $true) && ($is_oper($sockname) == $false)) {
        mIRCd.sraw $sockname $mIRCd.reply(481,$mIRCd.info($sockname,nick))
        return
      }
      mIRCd.doCommand $sockname $1-
      return
    }
    mIRCd.sraw $sockname $mIRCd.reply(421,$mIRCd.info($sockname,nick),$1)
    return
  }
}

; Commands and Functions

alias makeHost {
  ; $makeHost(<ip>)

  return $+($gettok($regsubex($upper($hmac($sha512($1), $+($longip($1),:,$mIRCd(SALT)), sha512, 0)),/(.{8})/g,\1.),1-3,46),.IP)
}
alias mIRCd.checkRegistering {
  ; /mIRCd.checkRegistering

  if ($hcount($mIRCd.unknown) == 0) { return }
  var %this.number = 0
  while (%this.number < $hcount($mIRCd.unknown)) {
    inc %this.number 1
    var %this.sock = $hget($mIRCd.unknown,%this.number).item
    if ($sock(%this.sock) == $null) {
      ; `-> Make sure the socket still exists. If it doesn't, something went wrong and it needs expunging.
      mIRCd.errorUser %this.sock $mIRCd.socketError
      continue
    }
    if ($sock(%this.sock).to >= $mIRCd(REGISTRATION_TIMEOUT_DURATION)) { mIRCd.errorUser %this.sock $mIRCd.registrationTimeout }
  }
}
alias mIRCd.createUser {
  ; /mIRCd.createUser <sockname> <socket they connected through>

  sockaccept $1
  mIRCd.sraw $1 NOTICE * :*** Processing your connection; please wait...
  hinc $mIRCd.temp totalCount 1
  hadd -m $mIRCd.unknown $1 $ctime
  mIRCd.updateUser $1 isReg 0
  mIRCd.updateUser $1 thruSock $2
  mIRCd.updateUser $1 host $sock($1).ip
  mIRCd.updateUser $1 trueHost $sock($1).ip
  if ($bool_fmt($mIRCd(DNS_USERS)) == $true) {
    if ((127.* !iswm $sock($1).ip) && (192.168.* !iswm $sock($1).ip)) {
      mIRCd.sraw $1 NOTICE * :*** Looking up your hostname...
      mIRCd.dnsUser $1 $sock($1).ip
    }
    ; `-> I'm still trying to decide if resolving localhost/LAN is a good or bad idea. (For now, I've made it so it won't look it up.)
  }
  if ($bool_fmt($mIRCd(ACCESS_IDENT_SERVER)) == $true) {
    mIRCd.sraw $1 NOTICE * :*** Checking ident...
    var %this.sock = $+(mIRCd.ident.,$gettok($1,-1,46))
    hadd -m $mIRCd.ident %this.sock $sock($1).port $+ , $gettok($2,-1,46)
    sockopen %this.sock $sock($1).ip 113
    /*
    var %this.command = sockopen %this.sock $sock($1).ip 113
    if ($mIRCd(LOOKUP_DELAY) > 0) { $+(.timermIRCd.ident,%this.sock) -o 1 0 %this.command }
    else { %this.command }
    */
  }
}
alias mIRCd.delUserItem {
  ; /mIRCd.delUserItem <sockname> <item>

  hdel $mIRCd.table($1) $2
}
alias mIRCd.destroyIdent {
  ; /mIRCd.destroyIdent <sockname>

  if ($hget($mIRCd.ident,$1).data != $null) { hdel $mIRCd.ident $1 }
  if ($sock($1) != $null) { sockclose $1 }
}
alias mIRCd.destroyUser {
  ; /mIRCd.destroyUser <sockname> [quit message]

  var %this.error = $mIRCd.info($1,error), %this.fulladdr = $mIRCd.fulladdr($1), %this.sock = $1
  if ($hget($mIRCd.unknown,%this.sock) == $null) { mIRCd.serverNotice 16384 Client quit: $mIRCd.info(%this.sock,nick) $parenthesis($gettok(%this.fulladdr,2,33)) }
  ; `-> Temporarily store the (error), fulladdr and name of the socket.
  if ($mIRCd.info(%this.sock,chans) != $null) {
    ; ¦-> The user is on channel(s). We need to display their quit to users who are in mutual channels.
    ; `-> It's probably quicker to check each user online than each channel one-by-one, then the users of those channels one-by-one.
    var %this.quit = $iif($2- != :,$decolonize($left($v1,$mIRCd(TOPICLEN))),$mIRCd.standardQuit)
    if (%this.error == $null) {
      if ($bool_fmt($mIRCd(PREFIX_QUIT)) == $true) { var %this.quit = Quit: %this.quit }
      ; `-> Just to stop people faking "Ping timeout" and other things; but only if PREFIX_QUIT=TRUE.
    }
    var %this.loop = 0
    while (%this.loop < $hcount($mIRCd.users)) {
      inc %this.loop 1
      var %this.otherSock = $hget($mIRCd.users,%this.loop).item
      if ($is_mutual(%this.sock,%this.otherSock) == $true) { mIRCd.raw %this.otherSock $+(:,%this.fulladdr) QUIT $+(:,%this.quit) }
    }
    ; ,-> Now delete them from the channel users.
    var %this.chan = 0, %this.chans = $mIRCd.info(%this.sock,chans)
    while (%this.chan < $numtok(%this.chans,44)) {
      inc %this.chan 1
      var %this.id = $gettok(%this.chans,%this.chan,44)
      mIRCd.chanDelUser %this.id %this.sock
    }
  }
  if ($hget($mIRCd.invisible,%this.sock) != $null) { hdel $mIRCd.invisible %this.sock }
  if ($hget($mIRCd.opersOnline,%this.sock) != $null) { hdel $mIRCd.opersOnline %this.sock }
  ; `-> Again, fiddle with /LUSERS numbers.
  if ($hget($mIRCd.unknown,%this.sock) != $null) { hdel $mIRCd.unknown %this.sock }
  if ($hget($mIRCd.users,%this.sock) != $null) { hdel $mIRCd.users %this.sock }
  if ($hget($mIRCd.silence(%this.sock)) != $null) { hfree $mIRCd.silence(%this.sock) }
  if ($hget($mIRCd.table(%this.sock)) != $null) { hfree $mIRCd.table(%this.sock) }
  if ($timer($+(mIRCd.ping,%this.sock)) != $null) { $+(.timermIRCd.ping,%this.sock) off }
  if ($sock(%this.sock) != $null) { sockclose %this.sock }
}
alias mIRCd.doCommand {
  ; /mIRCd.doCommand <sockname> <args>

  hinc -m $mIRCd.mStats $2 1
  [ [ $+(mIRCd_command_,$2) ] ] $1-
}
alias mIRCd.dnsUser {
  ; /mIRCd.dnsUser <sockname> <ip>

  hadd -m $mIRCd.dns $1 $2
  .dns $2
}
alias mIRCd.errorUser {
  ; /mIRCd.errorUser <sockname> <error message>

  mIRCd.raw $1 ERROR :Closing Link: $2-
  mIRCd.updateUser $1 error 1
  $+(.timermIRCd.error,$1) -o 1 0 mIRCd.destroyUser $1 $+(:,$2-)
}
alias mIRCd.fulladdr {
  ; $mIRCd.fulladdr(<sockname>)

  return $+($mIRCd.info($1,nick),!,$iif($mIRCd.info($1,ident) != $null,$v1,$mIRCd.info($1,user)),@,$mIRCd.info($1,host))
}
alias mIRCd.hostQuit {
  ; /mIRCd.hostQuit <sockname>

  if ($bool_fmt($mIRCd(HIDE_HOSTS_FREELY)) == $false) { return }
  ; `-> Do nothing for now. (If +r is part of modes - which is invisible and set via ACCOUNT, this should be <account>.users.localhost - or something.)
  var %this.host = $makeHost($sock($1).ip)
  if ($numtok($mIRCd.info($1,chans),44) == 0) {
    mIRCd.updateUser $1 host %this.host
    mIRCd.sraw $1 $mIRCd.reply(396,$mIRCd.info($1,nick),%this.host)
    return
  }
  var %this.fulladdr = $mIRCd.fulladdr($1), %this.newaddr = $+($gettok($mIRCd.fulladdr($1),1,64),@,%this.host)
  var %this.loop = 0
  while (%this.loop < $hcount($mIRCd.users)) {
    inc %this.loop 1
    var %this.sock = $hget($mIRCd.users,%this.loop).item
    if ($is_mutual($1,%this.sock) == $false) { continue }
    if ($1 != %this.sock) { mIRCd.raw %this.sock $+(:,%this.fulladdr) QUIT $colonize($mIRCd.hostChange) }
  }
  var %this.chan = 0
  while (%this.chan < $numtok($mIRCd.info($1,chans),44)) {
    inc %this.chan 1
    var %this.id = $gettok($mIRCd.info($1,chans),%this.chan,44)
    var %this.modeSock = $1
    ; `-> Required for %this.status.
    var %this.user = 0, %this.status = $regsubex($str(.,3),/./g,$iif($gettok($hget($mIRCd.chanUsers(%this.id),%this.modeSock),$calc(\n + 2),32) == 1,$mid(ohv,\n,1)))
    while (%this.user < $hcount($mIRCd.chanUsers(%this.id))) {
      inc %this.user 1
      var %this.chanSock = $hget($mIRCd.chanUsers(%this.id),%this.user).item
      if ($1 != %this.chanSock) {
        mIRCd.raw %this.chanSock $+(:,%this.newaddr) JOIN $mIRCd.info(%this.id,name)
        if (%this.status != $null) { mIRCd.sraw %this.chanSock MODE $mIRCd.info(%this.id,name) $+(+,%this.status) $str($+($mIRCd.info($1,nick),$chr(32)),$len(%this.status)) }
      }
    }
  }
  mIRCd.updateUser $1 host %this.host
  mIRCd.raw $1 $mIRCd.reply(396,$mIRCd.info($1,nick),%this.host)
}
alias mIRCd.info {
  ; $mIRCd.info(<chan ID|sockname>,<value>)

  return $hget($mIRCd.table($1),$2)
}
; `-> Channel and user info is taken from here.
alias mIRCd.ipaddr {
  ; $mIRCd.ipaddr(<sockname>)

  return $+($gettok($mIRCd.fulladdr($1),1,64),@,$sock($1).ip)
}
alias mIRCd.pingUsers {
  ; /mIRCd.pingUsers

  if ($hcount($mIRCd.users) == 0) { return }
  var %this.number = 0
  while (%this.number < $hcount($mIRCd.users)) {
    inc %this.number 1
    var %this.sock = $hget($mIRCd.users,%this.number).item
    if ($sock(%this.sock) == $null) {
      ; `-> Make sure the socket still exists. If it doesn't, something went wrong and it needs expunging.
      mIRCd.errorUser %this.sock $mIRCd.socketError
      continue
    }
    if ($calc($ctime - $mIRCd.info(%this.sock,lastPing)) >= $mIRCd(PING_TIMEOUT_DURATION)) {
      ; `-> Make sure to check the current timestamp vs. their last ping timestamp and then "Ping timeout" user(s).
      if ($mIRCd.info(%this.sock,isReg) == 1) { mIRCd.errorUser %this.sock $mIRCd.pingTimeout }
      ; `-> Ignore connecting user(s), they have their own routine.
      continue
    }
    if ($sock(%this.sock).to >= $int($calc($mIRCd(PING_TIMEOUT) / 2))) { mIRCd.raw %this.sock PING $+(:,$hget($mIRCd.temp,SERVER_NAME)) }
    ; `-> A little amnesty first. (No point pinging users who've just registered with the IRCd.)
  }
}
alias mIRCd.trueaddr {
  ; $mIRCd.trueaddr(<sockname>)

  return $+($gettok($mIRCd.fulladdr($1),1,64),@,$mIRCd.info($1,trueHost))
}
; `-> ipaddr and trueaddr are for ban checking only.
alias mIRCd.updateUser {
  ; /mIRCd.updateUser <sockname> <item> <value>

  hadd -m $mIRCd.table($1) $2 $3-
}
alias mIRCd.userLen { return 10 }
; `-> Trim the ident/user to ^ chars. Well, (N - 1) if the ident isn't found because we need to add ~.

; Error/Quit Messages

alias mIRCd.closeConnection { return Closed unknown connection(s) }
alias mIRCd.hostChange { return Changing host }
alias mIRCd.pingTimeout { return Ping timeout }
alias mIRCd.socketClosed { return Remote socket closed the connection }
alias mIRCd.socketError { return Socket error }
alias mIRCd.registrationTimeout { return Registration timeout }
alias mIRCd.standardQuit { return Disconnected }
; `-> Just a standard quit message if one wasn't specified.

; EOF
