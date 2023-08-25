; mIRCd_miscInfo.mrc
;
; This script contains the following command(s): ADMIN, HASH, INFO, LINKS, MAP, TIME

alias mIRCd_command_admin {
  ; /mIRCd_command_admin <sockname> ADMIN

  if ($mIRCd(ADMIN_LOC1) == $null) {
    ; `-> NOTE: The first line of ADMIN (LOC1) *is* required.
    mIRCd.sraw $1 $mIRCd.reply(423,$mIRCd.info($1,nick))
    return
  }
  mIRCd.sraw $1 $mIRCd.reply(256,$mIRCd.info($1,nick))
  mIRCd.sraw $1 $mIRCd.reply(257,$mIRCd.info($1,nick),$mIRCd(ADMIN_LOC1))
  if ($mIRCd(ADMIN_LOC2) != $null) { mIRCd.sraw $1 $mIRCd.reply(258,$mIRCd.info($1,nick),$mIRCd(ADMIN_LOC2)) }
  if ($mIRCd(ADMIN_EMAIL) != $null) { mIRCd.sraw $1 $mIRCd.reply(259,$mIRCd.info($1,nick),$mIRCd(ADMIN_EMAIL)) }
  ; `-> ADMIN (LOC2) and ADMIN (EMAIL) are entirely optional, however.
}
alias mIRCd_command_hash {
  ; /mIRCd_command_hash <sockname> HASH

  mIRCd.sraw $1 NOTICE $mIRCd.info($1,nick) :Hash Table Statistics:
  mIRCd.sraw $1 NOTICE $mIRCd.info($1,nick) :Channel entries: $hcount($mIRCd.chans)
  mIRCd.sraw $1 NOTICE $mIRCd.info($1,nick) :Client entries: $hcount($mIRCd.users)
  ; `-> Buckets - whatever they are - should also be part of this...
}
alias mIRCd_command_info {
  ; /mIRCd_command_info <sockname> INFO

  if ($lines($mIRCd.fileInfo) == 0) {
    mIRCd.sraw $1 $mIRCd.reply(424,$mIRCd.info($1,nick))
    return
  }
  var %this.loop = 0
  while (%this.loop < $lines($mIRCd.fileInfo)) {
    inc %this.loop 1
    mIRCd.sraw $1 $mIRCd.reply(371,$mIRCd.info($1,nick),- $replace($read($mIRCd.fileInfo, n, %this.loop), <thisVersion>, $mIRCd.version))
  }
  mIRCd.sraw $1 $mIRCd.reply(374,$mIRCd.info($1,nick))
  ; `-> Technically INFO is written in the source code; but I didn't want to do that. Honestly? It looks tacky as hell.
}
alias mIRCd_command_links {
  ; /mIRCd_command_links <sockname> LINKS

  mIRCd.sraw $1 $mIRCd.reply(364,$mIRCd.info($1,nick),$mIRCd(SERVER_NAME).temp,$mIRCd(SERVER_NAME).temp,$mIRCd.hopCount,$mIRCd(NETWORK_INFO))
  mIRCd.sraw $1 $mIRCd.reply(365,$mIRCd.info($1,nick))
}
alias mIRCd_command_map {
  ; /mIRCd_command_map <sockname> MAP

  mIRCd.sraw $1 $mIRCd.reply(015,$mIRCd.info($1,nick),$mIRCd(SERVER_NAME).temp,$hcount($mIRCd.users))
  ; >-> NUMERIC 016 = RPL_MOREMAP
  mIRCd.sraw $1 $mIRCd.reply(017,$mIRCd.info($1,nick))
}
; `-> re: LINKS/MAP, this is it for now!
alias mIRCd_command_time {
  ; /mIRCd_command_time <sockname> TIME

  mIRCd.sraw $1 $mIRCd.reply(391,$mIRCd.info($1,nick))
}

; Commands and Functions

alias -l mIRCd.fileInfo { return $+($scriptdirconf\INFO.txt) }

; EOF
