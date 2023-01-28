; mIRCd v0.09hf6 (Revision 2) - an IRCd scripted entirely in mSL - by Jigsy (https://github.com/Jigsy1/mIRCd)
;   "You were so preoccupied with whether or not you could, you didn't stop to think if you should." -Dr. Ian Malcolm (Jurrasic Park)
;
; Note: It is recommended running these scripts in a separate instance of mIRC - or in a Virtual Machine/under WINE.

menu Menubar {
  &mIRCd
  .&LOAD:{ mIRCd.load }
  .$iif($sock(mIRCd.*,0) > 0,&START $parenthesis(already running),&START):{ mIRCd.start }
  .-
  .$iif($sock(mIRCd.*,0) > 0,&DIE,&DIE $parenthesis(not running)):{ mIRCd.die }
  .$iif($sock(mIRCd.*,0) > 0,RE&HASH,RE&HASH $parenthesis(not running)):{ mIRCd.rehash }
  .$iif($sock(mIRCd.*,0) > 0,&RESTART,&RESTART $parenthesis(not running)):{ mIRCd.restart }
  .-
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

alias mIRCd.badNicks { return mIRCd[badNicks] }
alias mIRCd.chans { return mIRCd[Chans] }
alias mIRCd.chanBans { return $+(mIRCd[,$1,][Bans]) }
alias mIRCd.chanUsers { return $+(mIRCd[,$1,][Users]) }
alias mIRCd.dns { return mIRCd[DNS] }
alias mIRCd.ident { return mIRCd[Ident] }
alias mIRCd.invisible { return mIRCd[Invisible] }
; `-> +i will add them; -i or quitting will remove them.
alias mIRCd.main { return mIRCd }
alias mIRCd.mStats { return mIRCd[mStats] }
; `-> For: /STATS m/M
alias mIRCd.opers { return mIRCd[Opers] }
alias mIRCd.opersOnline { return mIRCd[OpersOnline] }
; `-> /OPER will add them; -o or qutting will remove them.
alias mIRCd.raws { return mIRCd[Raws] }
alias mIRCd.servers { return mIRCd[Servers] }
; `-> WARNING!: This isn't used (yet); but _DO NOT_ remove it. (re: /LUSERS)
alias mIRCd.silence { return $+(mIRCd[,$1,][Silence]) }
alias mIRCd.targMax { return mIRCd[TargMax] }
alias mIRCd.temp { return mIRCd[Temp] }
alias mIRCd.table { return $+(mIRCd[,$1,]) }
alias mIRCd.unknown { return mIRCd[Unknown] }
; `-> User(s) currently in the process of connecting to the server.
alias mIRCd.users { return mIRCd[Users] }
alias mIRCd.whoWas { return $+(mIRCd[WhoWas],$iif($1 != $null,$bracket($v1))) }

; Commands and Functions

alias _debugline { echo -aet [DEBUGLINE]: $1- }
; `-> Useful for hunting down annoying bugs.
alias bracket { return [[ $+ $$1- $+ ]] }
alias bool_fmt { return $iif($istok(1 on t true y yes,$1,32) == $true,$true,$false) }
alias colonize { return $iif($count($1-,:) == 0,$+(:,$gettok($1-,-1,32)),$gettok($1-,$+($findtok($1-,$matchtok($1-,:,1,32),1,32),-),32)) }
alias comma { return $chr(44) }
alias dollar { return $chr(36) }
alias decolonize { return $iif($left($1-,1) == :,$right($1-,-1),$1-) }
alias depolarize { return $iif($pos(-+,$left($1-,1)) != $null,$right($1-,-1),$1-) }
; `-> I don't believe this is used now, but retained it just incase.
alias hcount { return $hget($$1,0).data }
alias is_valid {
  ; $is_valid(<arg>)[.<chan|nick>]

  if ($prop == chan) {
    var %this.regex = /([#][^\x07\x2C\s])/
    return $bool_fmt($regex($1,%this.regex))
  }
  if ($prop == nick) {
    var %this.regex = /^([][A-Za-z_\\^`{|}][][\w\\^`{|}-]*)$/
    return $bool_fmt($regex($1,%this.regex))
  }
}
alias parenthesis { return ( $+ $$1- $+ ) }
alias mIRCd { return $hget($mIRCd.main,$1) }
alias mIRCd.commands {
  if ($1 == 0) { return NICK,PONG,POST,QUIT,USER }
  ; `-> Not registered with the IRCd. No other commands other than these five are permitted.
  if ($1 == 1) { return ADMIN,AWAY,CLEARMODE,CLOSE,DIE,ERROR,GET,GLINE,HASH,HELP,INFO,INVITE,ISON,JOIN,KICK,KILL,KNOCK,LINKS,LIST,LUSERS,MAP,MKPASSWD,MODE,MOTD,NAMES,NICK,NOTICE,OPER,OPMODE,PART,PING,PONG,POST,PRIVMSG,PROTOCTL,QUIT,REHASH,RESTART,SHUN,SILENCE,STATS,SVSJOIN,SVSNICK,SVSPART,TIME,TOPIC,USER,USERHOST,USERIP,VERSION,WALLCHOPS,WALLHOPS,WALLOPS,WALLUSERS,WALLVOICES,WHO,WHOWAS,WHOIS,ZLINE }
  ; `-> Registered with the IRCd.
  else { return ADMIN,PING,PONG,QUIT }
  ; `-> The user is shunned. No other commands other than these four are permitted.
}
; `-> I should really replace these with a hash table: mIRCd[Commands][0], mIRCd[Commands][1], etc.
alias mIRCd.fileBadNicks { return $qt($scriptdirconf\nicks.403) }
alias mIRCd.fileConf { return $qt($scriptdirmIRCd.ini) }
alias mIRCd.fileKlines { return $qt($scriptdirconf\mIRCd.klines) }
alias mIRCd.fileRaws { return $qt($scriptdirconf\mIRCd.raws) }
alias mIRCd.die {
  ; /mIRCd.die

  ; ,-> _EVERYTHING_ will be wiped aside from the config (including opers, targets, etc.) and raws.
  if ($sock(mIRCd.*,0) == 0) { return }
  if ($show == $true) { mIRCd.echo /mIRCd.die: done }
  mIRCd.serverNotice 1 Instruction received $iif($hget($mIRCd.temp,DIE) != $null,from $v1) to shutdown the server.
  .timermIRCd.die_ -o 1 1 mIRCd.die_
  ; `-> The instant death of the server means nobody ever sees the server notice; so add a short delay.
}
alias -l mIRCd.die_ {
  .timermIRCd.* off
  sockclose mIRCd.*
  hfree -w mIRCd[mIRCd.*
  ; `-> This should cover channel(s), channel user(s) and user(s) themselves.
  hfree -w $mIRCd.whoWas(*)
  var %this.tables = $mIRCd.dns , $mIRCd.chans , $mIRCd.glines , $mIRCd.ident , $mIRCd.invisible , $mIRCd.mStats , $mIRCd.opersOnline , $mIRCd.shuns , $mIRCd.temp , $mIRCd.unknown , $mIRCd.users , $mIRCd.whoWas , $mIRCd.zlines
  tokenize 44 %this.tables
  ; `-> A quick and dirty loop.
  scon -r if ( $!hget( $* ) ) { hfree $* }
}
alias mIRCd.rehash {
  ; /mIRCd.rehash [section]

  if ($mIRCd.check > 0) {
    mIRCd.echo /mIRCd.rehash: cannot rehash config due to errors; fix them first, then try again
    return
  }
  mIRCd.serverNotice 1 $iif($hget($mIRCd.temp,REHASH) != $null,$mIRCd.info($v1,nick),Admin) is rehashing Server config file
  if ($hget($mIRCd.temp,REHASH) != $null) {
    mIRCd.sraw $v1 $mIRCd.reply(382,$mIRCd.info($v1,nick),$gettok($noqt($mIRCd.fileConf),-1,92))
    hdel $mIRCd.temp REHASH
  }
  if ($1 != $null) {
    if ($1 == Klines) {
      if (($lines($mIRCd.fileKlines) > 0) && ($calc($lines($mIRCd.fileKlines) % 2) == 0)) { hload -m $mIRCd.klines $mIRCd.fileKlines }
    }
    if ($1 == Nicks) {
      if ($lines($mIRCd.fileBadNicks) > 0) { hload -mn $mIRCd.badNicks $mIRCd.fileBadNicks }
    }
    if ($1 == Raws) { hload -m $mIRCd.raws $mIRCd.fileRaws }
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
  ; >-> Just reload everything via /mIRCd.load. Next, we need to delete the removed items. We need to check five times.
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
; `-> I'm also not entirely with how hacky this is...
alias mIRCd.restart {
  ; /mIRCd.restart

  ; ,-> _EVERYTHING_ will be wiped aside from the config (including opers, targets, etc.) and raws.
  if ($sock(mIRCd.*,0) == 0) { return }
  if ($show == $true) { mIRCd.echo /mIRCd.restart: done }
  mIRCd.serverNotice 1 Instruction received $iif($hget($mIRCd.temp,RESTART) != $null,from $v1) to restart the server.
  .timermIRCd.restart_ -o 1 1 mIRCd.restart_
  ; `-> The instant death of the server means nobody ever sees the server notice; so add a short delay.
}
alias -l mIRCd.restart_ {
  .timermIRCd.* off
  sockclose mIRCd.*
  hfree -w mIRCd[mIRCd.*
  ; `-> This should cover channel(s), channel user(s) and user(s) themselves.
  hfree -w $mIRCd.whoWas(*)
  var %this.tables = $mIRCd.dns , $mIRCd.chans , $mIRCd.glines , $mIRCd.ident , $mIRCd.invisible , $mIRCd.mStats , $mIRCd.opersOnline , $mIRCd.shuns , $mIRCd.temp , $mIRCd.unknown , $mIRCd.users , $mIRCd.whoWas , $mIRCd.zlines
  tokenize 44 %this.tables
  scon -r if ( $!hget( $* ) ) { hfree $* }
  ; `-> A quick and dirty loop.
  .timermIRCd.restart -o 1 10 mIRCd.start
}
alias mIRCd.echo { !echo $+(-ac,$iif($active == Status Window,e)) "Info text" * $1- }
alias mIRCd.fakeIP { return 0.0.0.0 }
; `-> /WHO (if not oper), etc. (255.255.255.255 works too.)
alias mIRCd.load {
  ; /mIRCd.load

  if ($exists($mIRCd.fileConf) == $false) {
    mIRCd.echo /mIRCd.load: config is missing
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
  if ($ini($mIRCd.fileConf, Targets) != $null) { hload -im $mIRCd.targmax $mIRCd.fileConf Targets }
  ; `-> Targets (for TARGMAX) are loaded into a separate table.
  if ($ini($mIRCd.fileConf, Opers) != $null) { hload -im $mIRCd.opers $mIRCd.fileConf Opers }
  ; `-> Opers are loaded into a separate table.
  hload -m $mIRCd.raws $mIRCd.fileRaws
  if (($lines($mIRCd.fileKlines) > 0) && ($calc($lines($mIRCd.fileKlines) % 2) == 0)) { hload -m $mIRCd.klines $mIRCd.fileKlines }
  ; `-> Won't get loaded if the entries are an odd number.
  if ($lines($mIRCd.fileBadNicks) > 0) { hload -mn $mIRCd.badNicks $mIRCd.fileBadNicks }
  if ($show == $true) { mIRCd.echo /mIRCd.load: done }
}
alias mIRCd.loadScripts {
  var %these.scripts = $regsubex($str(.,$findfile($scriptdir,mIRCd_*.mrc,0)),/./g,$+($findfile($scriptdir,mIRCd_*.mrc,\n),¦))
  tokenize 166 %these.scripts
  scon -r if ( $!script( $* ) == $!null) { .load -rs $!qt( $* ) }
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
  sockwrite -nt $1 $+(:,$hget($mIRCd.temp,SERVER_NAME)) $2-
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
    if ($hget($mIRCd.temp,startTime) == $null) { hadd -m $mIRCd.temp startTime $ctime }
    if ($hget($mIRCd.temp,highCount) == $null) { hadd -m $mIRCd.temp highCount 0 }
    if ($hget($mIRCd.temp,totalCount) == $null) { hadd -m $mIRCd.temp totalCount 0 }
    ; `-> The last two are for stats tracking only.
    if ($hget($mIRCd.temp,DEFAULT_CHANMODES) == $null) { hadd -m $mIRCd.temp DEFAULT_CHANMODES $iif($mIRCd.makeDefaultModes($mIRCd(DEFAULT_CHANMODES)).chan != $null,$v1,$mIRCd.defaultChanModes) }
    if ($hget($mIRCd.temp,DEFAULT_USERMODES) == $null) { hadd -m $mIRCd.temp DEFAULT_USERMODES $mIRCd.makeDefaultModes($mIRCd(DEFAULT_USERMODES)).nick }
    if ($hget($mIRCd.temp,HALFOP) == $null) { hadd -m $mIRCd.temp HALFOP $iif($bool_fmt($mIRCd(HALFOP)) == $true,1,0) }
    if ($hget($mIRCd.temp,LOOSE_OBFUSCATION) == $null) { hadd -m $mIRCd.temp LOOSE_OBFUSCATION $iif($bool_fmt($mIRCd(LOOSE_OBFUSCATION)) == $true,1,0) }
    if ($hget($mIRCd.temp,OPER_OVERRIDE) == $null) { hadd -m $mIRCd.temp OPER_OVERRIDE $iif($bool_fmt($mIRCd(OPER_OVERRIDE)) == $true,1,0) }
    if ($hget($mIRCd.temp,PERSISTANT_CHANNELS) == $null) { hadd -m $mIRCd.temp PERSISTANT_CHANNELS $iif($bool_fmt($mIRCd(PERSISTANT_CHANNELS)) == $true,1,0) }
    if ($hget($mIRCd.temp,SALT) == $null) { hadd -m $mIRCd.temp SALT $mIRCd(SALT) }
    if ($hget($mIRCd.temp,SERVER_NAME) == $null) { hadd -m $mIRCd.temp SERVER_NAME $mIRCd(SERVER_NAME) }
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
  mIRCd.die
  .timermIRCd.hfree -o 1 5 hfree -w mIRCd*
  var %these.scripts = $regsubex($str(.,$findfile($scriptdir,mIRCd_*.mrc,0)),/./g,$+($findfile($scriptdir,mIRCd_*.mrc,\n),¦))
  tokenize 166 %these.scripts
  scon -r if ( $!script( $* ) ) { .unload -rs $!qt( $* ) }
  ; `-> A quick and dirty loop.
}
alias mIRCd.version { return mIRCd[0.09hf6(Rev.2)][2021-2023] }
alias mIRCd.window { return @mIRCd }
alias -l nextHour { return $+($asctime($calc($ctime + 3600),HH),:00) }
alias -l requiredVersion { return 7.66 }
; `-> Although I've modified this from a version higher than 7.66 (currently 7.72), this should still work on 7.66.

; EOF
