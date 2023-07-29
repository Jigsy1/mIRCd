; mIRCd v0.09hf14 (Revision 2) - an IRCd scripted entirely in mSL - by Jigsy (https://github.com/Jigsy1/mIRCd)
;   "You were so preoccupied with whether or not you could, you didn't stop to think if you should." -Dr. Ian Malcolm (Jurrasic Park)
;
; Note: It is recommended running these scripts in a separate instance of mIRC - or in a Virtual Machine/under WINE.

menu Menubar {
  &mIRCd
  .$iif($hget($mIRCd.main,0).data > 0,$style(2) &LOAD $parenthesis(please use rehash),&LOAD):{ mIRCd.load }
  .$iif($sock(mIRCd.*,0) > 0,$style(2) &START $parenthesis(already running),&START):{ mIRCd.start }
  .-
  .$iif($sock(mIRCd.*,0) > 0,&DIE,$style(2) &DIE $parenthesis(not running)):{ mIRCd.die }
  .RE&HASH:{ mIRCd.rehash }
  .$iif($sock(mIRCd.*,0) > 0,&RESTART,$style(2) &RESTART $parenthesis(not running)):{ mIRCd.restart }
  .-
  .&MKPASSWD:{ write -c $qt($scriptdirmkpasswd.txt) $mIRCd.encryptPass($input(Enter a password:,p,Enter a password)) }
  .$iif($window($mIRCd.window) != $null,$style(2)) &Information Window:{ window -ek0n $mIRCd.window }
}
on *:load:{
  if ($version >= $requiredVersion) {
    mIRCd.loadScripts
    return
  }
  mIRCd.echo mIRCd: unloading - mIRC version is not compatible; please use mIRC $requiredVersion or newer
  .unload -rs $qt($script)
}
on *:signal:mIRCd:{
  if ($istok(DIE LOAD REHASH RESTART START,$1,32) == $true) { [ $+(.mIRCd.,$lower($1)) ] }
  if ($1 == MKPASSWD) { write -c $qt($scriptdirmkpasswd.txt) $mIRCd.encryptPass($2) }
}
; `-> Note: This requires the following to work correctly: http://xise.nl/mirc/sigmirc.zip
on *:unload:{ mIRCd.unload }

; Hash Tables

alias mIRCd.accept { return $+(mIRCd,$bracket($1),[Accept]) }
alias mIRCd.badNicks { return mIRCd[BadNicks] }
alias mIRCd.chans { return mIRCd[Chans] }
alias mIRCd.chanBans { return $+(mIRCd,$bracket($1),[Bans]) }
alias mIRCd.chanUsers { return $+(mIRCd,$bracket($1),[Users]) }
alias mIRCd.commands { return $+(mIRCd[Commands],$bracket($1)) }
; `-> Unregistered = 0; Registered = 1; Shunned = 2.
alias mIRCd.dns { return mIRCd[DNS] }
alias mIRCd.ident { return mIRCd[Ident] }
alias mIRCd.invisible { return mIRCd[Invisible] }
; `-> +i will add them; -i or disconnecting will remove them.
alias mIRCd.main { return mIRCd }
alias mIRCd.mStats { return mIRCd[mStats] }
; `-> For: /STATS m/M
alias mIRCd.opers { return mIRCd[Opers] }
alias mIRCd.opersOnline { return mIRCd[OpersOnline] }
; `-> /OPER will add them; -o or disconnecting will remove them.
alias mIRCd.raws { return mIRCd[Raws] }
alias mIRCd.servers { return mIRCd[Servers] }
; `-> WARNING!: This isn't used (yet); but _DO NOT_ remove it. (re: /LUSERS)
alias mIRCd.silence { return $+(mIRCd,$bracket($1),[Silence]) }
alias mIRCd.targMax { return mIRCd[TargMax] }
alias mIRCd.temp { return mIRCd[Temp] }
alias mIRCd.table { return $+(mIRCd,$bracket($1)) }
; `-> Generic table call.
alias mIRCd.unknown { return mIRCd[Unknown] }
; `-> User(s) currently in the process of connecting to the server.
alias mIRCd.users { return mIRCd[Users] }
alias mIRCd.whoWas { return $+(mIRCd[WhoWas],$iif($1 != $null,$bracket($v1))) }

; Commands and Functions

alias _debugline { echo -aet [DEBUG]: $1- }
; `-> Useful for hunting down annoying bugs.
alias _stripMatch { return $remove($1-, !, <, =, >) }
alias _stripNumbers { return $remove($1-, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9) }
alias bracket { return [[ $+ $$1- $+ ]] }
alias bool_fmt { return $iif($istok(1 ok okay on one t tr true y yes,$1,32) == $true,$true,$false) }
alias colonize { return $iif($count($1-,:) == 0,$+(:,$gettok($1-,-1,32)),$gettok($1-,$+($findtok($1-,$matchtok($1-,:,1,32),1,32),-),32)) }
alias comma { return $chr(44) }
alias dollar { return $chr(36) }
alias decolonize { return $iif($left($1-,1) == :,$right($1-,-1),$1-) }
alias depolarize { return $iif($pos(-+,$left($1-,1)) != $null,$right($1-,-1),$1-) }
; `-> Note: I don't believe this is used anymore, but I've retained it just incase.
alias hcount { return $hget($$1,0).data }
alias is_valid {
  ; $is_valid(<arg>)[.<chan|nick|server>]

  if ($prop == chan) {
    var %this.regex = /([#][^\x07\x2C\s])/
    return $bool_fmt($regex($1,%this.regex))
  }
  if ($prop == nick) {
    var %this.regex = /^([][A-Za-z_\\^`{|}][][\w\\^`{|}-]*)$/
    return $bool_fmt($regex($1,%this.regex))
  }
  if ($prop == server) {
    ; ,-> I just hope this works. I really do. (By bkr on Stack Overflow.)
    var %this.regex = (?=^.{4,253}$)(^((?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.)+[a-zA-Z]{2,63}$)
    return $bool_fmt($regex($1,%this.regex))
  }
}
alias parenthesis { return ( $+ $$1- $+ ) }
alias mIRCd {
  ; $mIRCd(<item>)[.temp]

  return $hget($iif($prop != temp,$mIRCd.main,$mIRCd.temp),$1)
}
alias mIRCd.die {
  ; /mIRCd.die [-unload]

  ; ,-> _EVERYTHING_ will be wiped aside from the commands, config (including opers, targets, etc.), local K-lines/Shuns/Z-lines and raws.
  if (($sock(mIRCd.*,0) == 0) && ($1 != -unload)) { return }
  if ($show == $true) { mIRCd.echo /mIRCd.die: done }
  mIRCd.serverNotice 1 Instruction received $iif($mIRCd(DIE).temp != $null,from $v1) to shutdown the server.
  .timermIRCd.die_ -o 1 1 mIRCd.die_ $1
  ; `-> The instant death of the server means nobody ever sees the server notice; so add a short delay.
}
alias -l mIRCd.die_ {
  var %unload.flag = $1
  .timermIRCd.* off
  sockclose mIRCd.*
  hfree -w mIRCd[mIRCd.*
  ; `-> This should cover ban(s), channel(s), channel user(s), user(s), user accept(s) and user silence(s) themselves.
  hfree -w $mIRCd.whoWas(*)
  var %these.tables = $mIRCd.dns , $mIRCd.chans , $mIRCd.glines , $mIRCd.ident , $mIRCd.invisible , $mIRCd.mStats , $mIRCd.opersOnline , $mIRCd.shuns , $mIRCd.temp , $mIRCd.unknown , $mIRCd.users , $mIRCd.whoWas , $mIRCd.zlines
  tokenize 44 %these.tables
  ; `-> A quick and dirty loop.
  scon -r if ( $!hget( $* ) != $!null ) { hfree $* }
  if (%unload.flag == -unload) { mIRCd.unloadScripts }
}
alias mIRCd.fileBadNicks { return $qt($scriptdirconf\nicks.403) }
alias mIRCd.fileCommands { return $qt($scriptdirconf\cmds\) }
alias mIRCd.fileConf { return $qt($scriptdirmIRCd.ini) }
alias mIRCd.fileKlines { return $qt($scriptdirconf\mIRCd.klines) }
alias mIRCd.fileLocalShuns { return $qt($scriptdirconf\mIRCd.shuns) }
alias mIRCd.fileLocalZlines { return $qt($scriptdirconf\mIRCd.zlines) }
alias mIRCd.fileRaws { return $qt($scriptdirconf\mIRCd.raws) }
alias mIRCd.fileSlines { return $qt($scriptdirconf\mIRCd.slines) }
alias mIRCd.hopCount { return 0 }
alias mIRCd.rehash {
  ; /mIRCd.rehash [section]

  if ($mIRCd.check > 0) {
    mIRCd.echo /mIRCd.rehash: cannot rehash config due to errors; fix them first, then try again
    return
  }
  if ($sock(mIRCd.user.*,0) > 0) { mIRCd.serverNotice 1 $iif($mIRCd(REHASH).temp != $null,$mIRCd.info($v1,nick),Admin) is rehashing Server config file }
  if ($mIRCd(REHASH).temp != $null) {
    mIRCd.sraw $v1 $mIRCd.reply(382,$mIRCd.info($v1,nick),$gettok($noqt($mIRCd.fileConf),-1,92))
    hdel $mIRCd.temp REHASH
  }
  if ($1 != $null) {
    ; >-> Note: I was going to add Commands here, but decided not to.
    if ($1 == Klines) {
      if (($lines($mIRCd.fileKlines) > 0) && ($calc($lines($mIRCd.fileKlines) % 2) == 0)) { hload -m $mIRCd.klines $mIRCd.fileKlines }
    }
    if ($1 == Nicks) {
      if ($lines($mIRCd.fileBadNicks) > 0) { hload -mn $mIRCd.badNicks $mIRCd.fileBadNicks }
    }
    if ($1 == Raws) { hload -m $mIRCd.raws $mIRCd.fileRaws }
    if ($1 == Shuns) {
      if (($lines($mIRCd.fileLocalShuns) > 0) && ($calc($lines($mIRCd.fileLocalShuns) % 2) == 0)) { hload -m $mIRCd.local(Shuns) $mIRCd.fileLocalShuns }
    }
    if ($1 == Slines) {
      if (($lines($mIRCd.fileSlines) > 0) && ($calc($lines($mIRCd.fileSlines) % 2) == 0)) { hload -m $mIRCd.slines $mIRCd.fileSlines }
    }
    if ($1 == Zlines) {
      if (($lines($mIRCd.fileLocalZlines) > 0) && ($calc($lines($mIRCd.fileLocalZlines) % 2) == 0)) { hload -m $mIRCd.local(Zlines) $mIRCd.fileLocalZlines }
    }
    if ($1 == Server) { hload -im $mIRCd.main $mIRCd.fileConf Server }
    if ($1 == Mechanics) { hload -im $mIRCd.main $mIRCd.fileConf Mechanics }
    if ($1 == Admin) {
      if ($ini($mIRCd.fileConf, Admin) != $null) { hload -im $mIRCd.main $mIRCd.fileConf Admin }
    }
    if ($1 == Targets) {
      if ($ini($mIRCd.fileConf, Targets) != $null) { hload -im $mIRCd.main $mIRCd.fileConf Targets }
    }
    if ($1 == Opers) {
      if ($ini($mIRCd.fileConf, Opers) != $null) { hload -im $mIRCd.main $mIRCd.fileConf Opers }
    }
    goto processCleanup
  }
  .mIRCd.load
  ; >-> Just reload everything via /mIRCd.load. Next, we need to delete the removed items. We need to check numerous times.
  :processCleanup
  var %this.loop = $hcount($mIRCd.klines)
  while (%this.loop > 0) {
    var %this.item = $hget($mIRCd.Klines,%this.loop).item
    if ($read($mIRCd.fileKlines, w, %this.item) == $null) { hdel $mIRCd.klines %this.item }
    dec %this.loop 1
  }
  var %this.loop = $hcount($mIRCd.badNicks)
  while (%this.loop > 0) {
    var %this.item = $hget($mIRCd.badNicks,%this.loop).data
    if ($read($mIRCd.fileBadNicks, w, %this.item) == $null) { hdel $mIRCd.badNicks %this.item }
    dec %this.loop 1
  }
  var %this.loop = $hcount($mIRCd.local(Shuns))
  while (%this.loop > 0) {
    var %this.item = $hget($mIRCd.local(Shuns),%this.loop).item
    if ($read($mIRCd.fileLocalShuns, w, %this.item) == $null) { hdel $mIRCd.local(Shuns) %this.item }
    dec %this.loop 1
  }
  var %this.loop = $hcount($mIRCd.local(Zlines))
  while (%this.loop > 0) {
    var %this.item = $hget($mIRCd.local(Zlines),%this.loop).item
    if ($read($mIRCd.fileLocalZlines, w, %this.item) == $null) { hdel $mIRCd.local(Zlines) %this.item }
    dec %this.loop 1
  }
  var %this.loop = $hcount($mIRCd.slines)
  while (%this.loop > 0) {
    var %this.item = $hget($mIRCd.slines,%this.loop).item
    if ($read($mIRCd.fileSlines, w, %this.item) == $null) { hdel $mIRCd.slines %this.item }
    dec %this.loop 1
  }
  var %this.loop = $hcount($mIRCd.main)
  while (%this.loop > 0) {
    var %this.item = $hget($mIRCd.main,%this.loop).item
    if ($read($mIRCd.fileConf, nw, $+(%this.item,=,*)) == $null) { hdel $mIRCd.main %this.item }
    dec %this.loop 1
  }
  var %this.loop = $hcount($mIRCd.targMax)
  while (%this.loop > 0) {
    var %this.item = $hget($mIRCd.targMax,%this.loop).item
    if ($read($mIRCd.fileConf, nw, $+(%this.item,=,*)) == $null) { hdel $mIRCd.targMax %this.item }
    dec %this.loop 1
  }
  var %this.loop = $hcount($mIRCd.opers)
  while (%this.loop > 0) {
    var %this.item = $hget($mIRCd.opers,%this.loop).item
    if ($read($mIRCd.fileConf, nw, $+(%this.item,=,*)) == $null) { hdel $mIRCd.opers %this.item }
    dec %this.loop 1
  }
}
; `-> I'm also not entirely happy with how hacky this is...
alias mIRCd.restart {
  ; /mIRCd.restart

  ; ,-> _EVERYTHING_ will be wiped aside from the commands, config (including opers, targets, etc.), local K-lines/Shuns/Z-lines and raws.
  if ($sock(mIRCd.*,0) == 0) { return }
  if ($show == $true) { mIRCd.echo /mIRCd.restart: done }
  mIRCd.serverNotice 1 Instruction received $iif($mIRCd(RESTART).temp != $null,from $v1) to restart the server.
  .timermIRCd.restart_ -o 1 1 mIRCd.restart_
  ; `-> The instant death of the server means nobody ever sees the server notice; so add a short delay.
}
alias -l mIRCd.restart_ {
  .timermIRCd.* off
  sockclose mIRCd.*
  hfree -w mIRCd[mIRCd.*
  ; `-> This should cover ban(s), channel(s), channel user(s), user(s), user accept(s) and user silence(s) themselves.
  hfree -w $mIRCd.whoWas(*)
  var %these.tables = $mIRCd.dns , $mIRCd.chans , $mIRCd.glines , $mIRCd.ident , $mIRCd.invisible , $mIRCd.mStats , $mIRCd.opersOnline , $mIRCd.shuns , $mIRCd.temp , $mIRCd.unknown , $mIRCd.users , $mIRCd.whoWas , $mIRCd.zlines
  tokenize 44 %these.tables
  scon -r if ( $!hget( $* ) != $!null ) { hfree $* }
  ; `-> A quick and dirty loop.
  .timermIRCd.restart -o 1 10 mIRCd.start
}
alias mIRCd.echo { !echo $+(-ac,$iif($active == Status Window,e)) "Info text" * $1- }
alias mIRCd.fakeIP { return 0.0.0.0 }
; `-> /WHO (if not oper), etc. (Using 255.255.255.255 works too.)
alias mIRCd.load {
  ; /mIRCd.load

  if ($lines($mIRCd.fileConf) == 0) {
    mIRCd.echo /mIRCd.load: config is empty, missing or has been renamed
    return
  }
  if ($mIRCd.check > 0) {
    mIRCd.echo /mIRCd.load: cannot load config due to errors; fix them first, then try again
    return
  }
  var %these.sections = Server,Mechanics,Features
  tokenize 44 %these.sections
  scon -r hload -im $mIRCd.main $mIRCd.fileConf $*
  if ($ini($mIRCd.fileConf, Admin) != $null) { hload -im $mIRCd.main $mIRCd.fileConf Admin }
  ; `-> Loaded into the main table, but this section is entirely optional.
  if ($ini($mIRCd.fileConf, Targets) != $null) { hload -im $mIRCd.targmax $mIRCd.fileConf Targets }
  ; `-> Targets (for TARGMAX) are loaded into a separate table.
  if ($ini($mIRCd.fileConf, Opers) != $null) { hload -im $mIRCd.opers $mIRCd.fileConf Opers }
  ; `-> Opers are loaded into a separate table.
  mIRCd.loadCommands
  if ($result != LOAD_OK) {
    mIRCd.echo /mIRCd.load: failed to load commands (files are empty or have been renamed); fix them first, then try again
    return
  }
  hload -m $mIRCd.raws $mIRCd.fileRaws
  if (($lines($mIRCd.fileKlines) > 0) && ($calc($lines($mIRCd.fileKlines) % 2) == 0)) { hload -m $mIRCd.klines $mIRCd.fileKlines }
  ; `-> Won't get loaded if the entries are an odd number.
  if ($lines($mIRCd.fileBadNicks) > 0) { hload -mn $mIRCd.badNicks $mIRCd.fileBadNicks }
  if (($lines($mIRCd.fileLocalShuns) > 0) && ($calc($lines($mIRCd.fileLocalShuns) % 2) == 0)) { hload -m $mIRCd.local(Shuns) $mIRCd.fileLocalShuns }
  if (($lines($mIRCd.fileLocalZlines) > 0) && ($calc($lines($mIRCd.fileLocalZlines) % 2) == 0)) { hload -m $mIRCd.local(Zlines) $mIRCd.fileLocalZlines }
  ; `-> Same as K-lines.
  if (($lines($mIRCd.fileSlines) > 0) && ($calc($lines($mIRCd.fileSlines) % 2) == 0)) { hload -m $mIRCd.slines $mIRCd.fileSlines }
  hadd -m $mIRCd.main NETWORK_INFO $left($mIRCd(NETWORK_INFO),50)
  ; `-> Truncate NETWORK_INFO to the same length as a "real name." (50 characters.)
  hadd -m $mIRCd.main NETWORK_NAME $left($mIRCd(NETWORK_NAME),200)
  ; ¦-> Testing on another ircu IRCd (bircd), there doesn't seem to be(?) a limit on the length of a NETWORK_NAME, so let's impose one.
  ; `-> If I'm wrong and there is (I'm guessing probably 512 characters), let me know via Github: https://github.com/Jigsy1/mIRCd/issues
  hadd -m $mIRCd.main NETWORK_NAME $legalizeIdent($mIRCd(NETWORK_NAME))
  ; `-> Make the NETWORK_NAME conform to naming conventions, which the nearest I can gather is the same as ident rules.
  if ($show == $true) { mIRCd.echo /mIRCd.load: done }
}
alias mIRCd.loadCommands {
  ; /mIRCd.loadCommands

  if ($findfile($noqt($mIRCd.fileCommands),*.cmds,0) != 3) { return }
  var %these.files = $left($regsubex($str(.,3),/./g,$+($gettok($findfile($noqt($mIRCd.fileCommands),*.cmds,\n),-1,92),$comma)),-1), %these.numbers = Unregistered 0,Registered 1,Shunned 2
  ; ,-> We have to use a while loop, sadly. $* doesn't work well with a large number of $identifiers...
  var %this.loop = 0
  while (%this.loop < $numtok(%these.numbers,44)) {
    inc %this.loop 1
    var %this.file = $gettok(%these.files,%this.loop,44)
    if ($matchtokcs(%these.numbers,$gettok(%this.file,1,46),1,44) == $null) { return }
    if ($lines($qt($+($noqt($mIRCd.fileCommands),%this.file))) == 0) { return }
    hload -mn $mIRCd.commands($gettok($matchtokcs(%these.numbers,$gettok(%this.file,1,46),1,44),2,32)) $qt($+($noqt($mIRCd.fileCommands),%this.file))
  }
  return LOAD_OK
}
alias mIRCd.loadScripts {
  var %these.scripts = $regsubex($str(.,$findfile($scriptdir,mIRCd_*.mrc,0)),/./g,$+($findfile($scriptdir,mIRCd_*.mrc,\n),¦))
  tokenize 166 %these.scripts
  scon -r if ( $!script( $* ) == $!null ) { .load -rs $!qt( $* ) }
  ; `-> A quick and dirty loop.
}
alias mIRCd.raw {
  ; /mIRCd.raw <sockname> <args>

  if ($sock($1) == $null) { return }
  sockwrite -nt $1 $2-
  if ($window($mIRCd.window) != $null) { echo -ci2t "Info text" $v1 [W]: $1 <- $2- }
}
alias mIRCd.reply {
  ; $mIRCd.reply(<numeric>,<nick>[,<args>[,...,...]])

  return $1 $2 [ [ $hget($mIRCd.raws,$1) ] ]
}
alias mIRCd.sraw {
  ; /mIRCd.sraw <sockname> <args>

  if ($sock($1) == $null) { return }
  sockwrite -nt $1 $+(:,$mIRCd(SERVER_NAME).temp) $2-
  if ($window($mIRCd.window) != $null) { echo -ci2t "Info text" $v1 [W]: $1 <- $2- }
}
alias mIRCd.start {
  ; /mIRCd.start

  if ($hcount($mIRCd.main) == 0) {
    mIRCd.echo /mIRCd.start: failed to start - /mIRCd.load the config first
    return
  }
  var %this.loop = 0, %this.open = 0
  while (%this.loop < $numtok($mIRCd(CLIENT_PORTS),44)) {
    inc %this.loop 1
    var %this.port = $gettok($mIRCd(CLIENT_PORTS),%this.loop,44)
    if ($sock($+(mIRCd.,%this.port)) != $null) {
      mIRCd.echo /mIRCd.start: $+(mIRCd.,%this.port) is already in use
      continue
    }
    if ($portfree(%this.port) != $true) {
      mIRCd.echo /mIRCd.start: port %this.port is already in use
      continue
    }
    socklisten $+(mIRCd.,%this.port) %this.port
    inc %this.open 1
  }
  if (%this.open > 0) {
    if ($mIRCd(startTime).temp == $null) { hadd -m $mIRCd.temp startTime $ctime }
    if ($mIRCd(highCount).temp == $null) { hadd -m $mIRCd.temp highCount 0 }
    if ($mIRCd(totalCount).temp == $null) { hadd -m $mIRCd.temp totalCount 0 }
    ; `-> The last two are for stats tracking only.
    if ($mIRCd(AUDITORIUM_MODE).temp == $null) { hadd -m $mIRCd.temp AUDITORIUM_MODE $iif($bool_fmt($mIRCd(AUDITORIUM_MODE)) == $true,1,0) }
    if (($mIRCd(AUTOJOIN_CHANS).temp == $null) && ($mIRCd.makeAutoJoin != $null)) { hadd -m $mIRCd.temp AUTOJOIN_CHANS $v1 }
    if ($mIRCd(BANDWIDTH_MODE).temp == $null) { hadd -m $mIRCd.temp BANDWIDTH_MODE $iif($bool_fmt($mIRCd(BANDWIDTH_MODE)) == $true,1,0) }
    if ($mIRCd(BOT_SUPPORT).temp == $null) { hadd -m $mIRCd.temp BOT_SUPPORT $iif($bool_fmt($mIRCd(BOT_SUPPORT)) == $true,1,0) }
    if ($mIRCd(HALFOP).temp == $null) { hadd -m $mIRCd.temp HALFOP $iif($bool_fmt($mIRCd(HALFOP)) == $true,1,0) }
    if ($mIRCd(LOOSE_OBFUSCATION).temp == $null) { hadd -m $mIRCd.temp LOOSE_OBFUSCATION $iif($bool_fmt($mIRCd(LOOSE_OBFUSCATION)) == $true,1,0) }
    if ($mIRCd(OPER_OVERRIDE).temp == $null) { hadd -m $mIRCd.temp OPER_OVERRIDE $iif($bool_fmt($mIRCd(OPER_OVERRIDE)) == $true,1,0) }
    if ($mIRCd(PERSISTANT_CHANNELS).temp == $null) { hadd -m $mIRCd.temp PERSISTANT_CHANNELS $iif($bool_fmt($mIRCd(PERSISTANT_CHANNELS)) == $true,1,0) }
    if ($mIRCd(SLINE_SUPPORT).temp == $null) { hadd -m $mIRCd.temp SLINE_SUPPORT $iif($bool_fmt($mIRCd(SLINE_SUPPORT)) == $true,1,0) }
    if ($mIRCd(WHOIS_PARANOIA).temp == $null) { hadd -m $mIRCd.temp WHOIS_PARANOIA $iif($bool_fmt($mIRCd(WHOIS_PARANOIA)) == $true,1,0) }
    if ($mIRCd(DEFAULT_CHANMODES).temp == $null) { hadd -m $mIRCd.temp DEFAULT_CHANMODES $iif($mIRCd.makeDefaultModes($mIRCd(DEFAULT_CHANMODES)).chan != $null,$v1,$mIRCd.defaultChanModes) }
    if ($mIRCd(DEFAULT_USERMODES).temp == $null) { hadd -m $mIRCd.temp DEFAULT_USERMODES $mIRCd.makeDefaultModes($mIRCd(DEFAULT_USERMODES)).nick }
    if ($mIRCd(SALT).temp == $null) { hadd -m $mIRCd.temp SALT $mIRCd(SALT) }
    if ($mIRCd(SERVER_NAME).temp == $null) { hadd -m $mIRCd.temp SERVER_NAME $mIRCd(SERVER_NAME) }
    ; `-> WARNING!: These may not be modified when the IRCd is already running.
    if ($timer(mIRCd.checkRegistering) == $null) { .timermIRCd.checkRegistering -o 0 $mIRCd(REGISTRATION_DURATION) mIRCd.checkRegistering }
    if ($timer(mIRCd.pingUsers) == $null) { .timermIRCd.pingUsers -o 0 $mIRCd(PING_DURATION) mIRCd.pingUsers }
    if ($timer(mIRCd.cleanWhoWas) == $null) { .timermIRCd.startCleanWhoWas -o $nextHour 1 1 mIRCd.startCleanWhoWas }
    ; ¦-> For automatically cleaning the /WHOWAS cache. (As this isn't important, I'd say check every hour to see if anything needs purging.)
    ; ¦-> This needs to be active even if CACHE_WHOWAS=FALSE due to the fact that someone might set it to TRUE then /REHASH.
    ; `-> This will start automatically on the next hour. (So if you start the IRCd at, for example, 21:47, it will start at 22:00.)
    if ($timer(mIRCd.timeCheck) == $null) { .timermIRCd.timeCheck -o 0 1 .signal -n mIRCd_timeCheck }
    ; `-> For automatically expiring G-lines, shuns and Z-lines.
    if ($show == $true) { mIRCd.echo /mIRCd.start: now running }
  }
}
alias mIRCd.startCleanWhoWas { .timermIRCd.cleanWhoWas -o 0 3600 .signal -n mIRCd_cleanWhoWas }
alias mIRCd.unload {
  if ($sock(mIRCd.*,0) > 0) {
    mIRCd.die -unload
    return
  }
  mIRCd.unloadScripts
}
alias mIRCd.unloadScripts {
  .timermIRCd.hfree -o 1 5 hfree -w mIRCd*
  var %these.scripts = $regsubex($str(.,$findfile($scriptdir,mIRCd_*.mrc,0)),/./g,$+($findfile($scriptdir,mIRCd_*.mrc,\n),¦))
  tokenize 166 %these.scripts
  scon -r if ( $!script( $* ) != $!null ) { .unload -rs $!qt( $* ) }
  ; `-> A quick and dirty loop.
  if ($script($script) != $null) { .unload -rs $qt($script) }
}
alias mIRCd.version { return mIRCd[0.09hf14(Rev.2)][2021-2023] }
alias mIRCd.window { return @mIRCd }
alias -l nextHour { return $+($asctime($calc($ctime + 3600),HH),:00) }
alias -l requiredVersion { return 7.66 }
; `-> Note: Although I've since modified this from a version of mIRC higher than 7.66 (currently 7.73), this should still work on 7.66.

; EOF
