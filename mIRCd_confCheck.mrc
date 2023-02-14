; mIRCd_confCheck.mrc
;
; Note: This script needs to be loaded all the time. However, if you want to run this once just to make sure your config is okay,
;       then unload it, you will need to add (without the ; obv.)...
;
; alias mIRCd.check { return 0 }
;
; ...to mIRCd.mrc. But I will _not_ be accountable for your config being wrong if you modify it post that.
;
; Also, I'm not entirely happy with this script. Don't get me wrong, it works. I just wish it was slightly more condensed.

alias mIRCd.check {
  ; /mIRCd.check

  if ($lines($mIRCd.fileConf) == 0) {
    mIRCd.echo /mIRCd.check: config is empty, missing or has been renamed
    return 1
  }
  var %this.section = Server
  if ($readini($mIRCd.fileConf, %this.section, CLIENT_PORTS) == $null) {
    mIRCd.echo $+($bracket(%this.section),:) CLIENT_PORTS cannot be blank.
    return 1
  }
  var %this.item = $v1
  if ($count($regsubex($str(.,$numtok(%this.item,44)),/./g,$iif($gettok(%this.item,\n,44) isnum 1-65535,1,0)),0) > 0) {
    mIRCd.echo $+($bracket(%this.section),:) CLIENT_PORTS must contain a port with a numerical value between 1 and 65535. (Standard plaintext port is 6667.)
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, NETWORK_INFO) == $null) {
    mIRCd.echo $+($bracket(%this.section),:) NETWORK_INFO cannot be blank.
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, NETWORK_NAME) == $null) {
    mIRCd.echo $+($bracket(%this.section),:) NETWORK_NAME cannot be blank.
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, SERVER_NAME) == $null) {
    mIRCd.echo $+($bracket(%this.section),:) SERVER_NAME cannot be blank.
    return 1
  }
  var %this.serverName = $v1
  if ($is_valid(%this.serverName).server == $false) {
    mIRCd.echo $+($bracket(%this.section),:) SERVER_NAME is invalid. It must conform the rules of a domain.tld.
    return 1
  }
  var %this.section = Mechanics
  if ($readini($mIRCd.fileConf, %this.section, AWAYLEN) !isnum 1-) {
    mIRCd.echo $+($bracket(%this.section),:) AWAYLEN must be a numerical value greater than 1.
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, DEFAULT_SNOMASK) !isnum 1-65535) {
    mIRCd.echo $+($bracket(%this.section),:) DEFAULT_SNOMASK must be a numerical value between 1 and 65535.
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, KEYLEN) !isnum 1-23) {
    mIRCd.echo $+($bracket(%this.section),:) KEYLEN must be a numerical value between 1 and 23.
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, KICKLEN) !isnum 1-) {
    mIRCd.echo $+($bracket(%this.section),:) KICKLEN must be a numerical value greater than 1.
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, MAXBANS) !isnum 1-) {
    mIRCd.echo $+($bracket(%this.section),:) MAXBANS must be a numerical value greater than 1.
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, MAXACCEPT) !isnum 1-) {
    mIRCd.echo $+($bracket(%this.section),:) MAXACCEPT must be a numerical value greater than 1.
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, MAXCHANNELS) !isnum 1-) {
    mIRCd.echo $+($bracket(%this.section),:) MAXCHANNELS must be a numerical value greater than 1.
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, MAXCHANNELLEN) !isnum 2-200) {
    mIRCd.echo $+($bracket(%this.section),:) MAXCHANNELLEN must be a numerical value between 2 and 200.
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, MAXNICKLEN) !isnum 1-32) {
    mIRCd.echo $+($bracket(%this.section),:) MAXNICKLEN must be a numerical value between 1 and 32.
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, MAXSILENCE) !isnum 1-) {
    mIRCd.echo $+($bracket(%this.section),:) MAXSILENCE must be a numerical value greater than 1.
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, MODESPL) !isnum 3-) {
    mIRCd.echo $+($bracket(%this.section),:) MODESPL must be a numerical value three or greater.
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, NICK_CHANGE_THROTTLE) !isnum 1-) {
    mIRCd.echo $+($bracket(%this.section),:) NICK_CHANGE_THROTTLE must be a numerical value greater than 1.
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, PING_DURATION) !isnum 60-) {
    mIRCd.echo $+($bracket(%this.section),:) PING_DURATION must be a numerical value greater than 60 seconds.
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, PING_TIMEOUT_DURATION) !isnum 60-) {
    mIRCd.echo $+($bracket(%this.section),:) PING_TIMEOUT_DURATION must be a numerical value greater than 60 seconds.
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, REGISTRATION_DURATION) !isnum 60-) {
    mIRCd.echo $+($bracket(%this.section),:) REGISTRATION_DURATION must be a numerical value greater than 60 seconds.
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, REGISTRATION_TIMEOUT_DURATION) !isnum 60-) {
    mIRCd.echo $+($bracket(%this.section),:) REGISTRATION_TIMEOUT_DURATION must be a numerical value greater than 60 seconds.
    return 1
  }
  if ($readini($mIRCd.fileConf, n, %this.section, SALT) == $null) {
    mIRCd.echo $+($bracket(%this.section),:) SALT cannot be blank.
    return 1
  }
  if ($readini($mIRCd.fileConf, %this.section, TOPICLEN) !isnum 1-) {
    mIRCd.echo $+($bracket(%this.section),:) TOPICLEN must be a numerical value greater than 1.
    return 1
  }
  var %this.section = Admin
  if ($ini($mIRCd.fileConf, %this.section) == $null) { return 0 }
  ; `-> Admin itself is entirely optional.
  if ($readini($mIRCd.fileConf, %this.section, ADMIN_LOC1) == $null) {
    mIRCd.echo $+($bracket(%this.section),:) ADMIN_LOC1 cannot be blank.
    return 1
  }
  return 0
}

; Commands and Functions

alias bool_check { return $iif($istok(FALSE TRUE,$1,32) == $true,$true,$false) }

; EOF
