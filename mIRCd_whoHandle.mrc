; mIRCd_whoHandle.mrc - This is probably not perfect...
;
; This script contains the following command(s): WHO

alias mIRCd_command_who {
  ; /mIRCd_command_who <sockname> WHO <terms[,...]> [matchflags][%includeflags] [:search]

  if ($mIRCd(WHO_THROTTLE) isnum 1-) {
    if (($calc($ctime - $iif($mIRCd.info($1,whoTime) != $null,$v1,$ctime)) <= $mIRCd(WHO_THROTTLE)) && ($is_oper($1) == $false)) {
      mIRCd.sraw $1 NOTICE $mIRCd.info($1,nick) :*** Notice -- This command is rate limited. Please try again later.
      return
    }
  }
  var %this.numeric = 352, %this.field = $mIRCd.whoDefaults, %this.string = <chan> <user> <host> <server> <nick> <flags> <:hopcount> <realName>
  ; `-> Default(s).
  if ($is_oper($1) == $true) { var %this.oper = 1 }
  if (($5 == $null) || ($len($5) == $len($decolonize($5)))) { var %this.blank = 1 }
  ; `-> Previously: ... || ($5 == :) || ...
  if ($4 != $null) {
    var %this.loop = 0, %this.field = $null, %this.include = $null
    while (%this.loop < $len($4)) {
      inc %this.loop 1
      var %this.char = $mid($4,%this.loop,1)
      if (%this.char == $chr(37)) {
        var %this.postField = 1
        continue
      }
      if (%this.postField == 1) {
        if ($pos(acdfhilnrsu,%this.char,1) == $null) { continue }
        if ($pos(%this.include,%this.char,1) != $null) { continue }
        var %this.include = $+(%this.include,%this.char)
        continue
      }
      if ($pos(hijnoru,%this.char,1) == $null) { continue }
      if ($pos(%this.field,%this.char,1) != $null) { continue }
      var %this.field = $+(%this.field,%this.char)
    }
    if (%this.include != $null) {
      var %this.numeric = 354, %this.order = cuihsnfdlar, %this.long = c <chan>,u <user>,i <ip>,h <host>,s <server>,n <nick>,f <flags>,d <hopcount>,l <idle>,a <account>,r <:realName>
      var %this.string = $regsubex($str(.,$len(%this.order)),/./g,$iif($mid(%this.order,\n,1) isin %this.include,$+($gettok($wildtok(%this.long,$mid(%this.include,$pos(%this.include,$mid(%this.order,\n,1)),1) <*>,1,44),2,32),$chr(32))))
    }
    if (n isin %this.field) { var %this.nFlag = 1 }
    ; `-> A very specific skipping flag. It needs to be set BEFORE the line below.
    if (%this.field == $null) { var %this.field = $mIRCd.whoDefaults }
    ; `-> Fall back to defaults.
  }
  var %this.who = $3, %this.flag = $null
  if ($hget($mIRCd.targMax,TARGMAX_WHO) isnum 1-) { var %this.who = $deltok(%this.who,$+($calc($v1 + 1),-),44) }
  if (%this.who == $null) { var %this.who = * }
  var %this.loop = 0
  while (%this.loop < $numtok(%this.who,44)) {
    if (%this.id != $null) { var %this.chanSeen = %this.chanSeen %this.id, %this.id = $null }
    if (%this.saw != $null) { var %this.sockSeen = %this.sockSeen %this.saw, %this.saw = $null }
    inc %this.loop 1
    var %this.item = $gettok(%this.who,%this.loop,44), %this.target = $null
    if ($istok($gettok(%this.who,$+($calc(%this.loop - 1),--),44),%this.item,44) == $true) { continue }
    if ((%this.item == 0) || ($count(%this.item,?) > 0) || ($count(%this.item,*) > 0)) {
      ; `-> Save wildcard searches for last. Mainly because if we return data, they'll be ignored entirely.
      var %this.wild = %this.wild %this.item
      continue
    }
    if (%this.blank == 1) {
      if ($is_valid(%this.item).chan == $true) {
        var %this.target = chan
        if ($is_exists(%this.item).chan == $true) { var %this.id = $getChanID(%this.item) }
      }
      if ($numtok(%this.who,44) == 1) {
        ; `-> Matchfield. (Cannot be done if there is more than one comma separated token delimeter. (See link below.))
        if (%this.target == $null) { var %this.target = field }
      }
      if ($istok(chan field,%this.target,32) == $true) {
        var %this.uloop = 0
        while (%this.uloop < $hcount($mIRCd.users)) {
          ; >-> 2048 / (number_of_fields + 4)
          var %this.operMatch = 0, %this.trueHostMatch = 0, %this.hostMatch = 0, %this.ipMatch = 0, %this.onlineMatch = 0, %this.nickMatch = 0, %this.nameMatch = 0, %this.userMatch = 0
          if (%this.saw != $null) { var %this.sockSeen = %this.sockSeen %this.saw, %this.saw = $null }
          inc %this.uloop 1
          var %this.usock = $hget($mIRCd.users,%this.uloop).item
          if ($istok(%this.sockSeen,%this.usock,32) == $true) { continue }
          if (($mIRCd.chanSeen(%this.chanSeen,%this.usock) > 0) && ($mIRCd.chanSeen(%this.secret,%this.usock) == 0)) { continue }
          if (%this.target == chan) {
            if ($istok($mIRCd.info(%this.usock,chans),%this.id,44) == $false) { continue }
            if ($is_modeSet(%this.id,s).chan == $true) {
              if (($is_on(%this.id,$1) == $false) && (%this.oper != 1)) {
                if ($istok(%this.secret,%this.id,32) == $false) { var %this.secret = %this.secret %this.id }
                continue
              }
            }
          }
          if ($is_modeSet(%this.usock,i).nick == $true) {
            if (%this.item != $mIRCd.info(%this.usock,nick)) {
              if (($1 != %this.usock) && ($is_mutual($1,%this.usock) == $false) && (%this.oper != 1)) {
                if ($istok(%this.invisible,%this.usock,32) == $false) { var %this.invisible = %this.invisible %this.usock }
                continue
              }
            }
          }
          ; ,-> Match flags do not matter for channel(s).
          if (%this.target == field) {
            if (o isin %this.field) {
              if ($is_oper(%this.usock) == $false) { continue }
              var %this.operMatch = 1
            }
            if (h isin %this.field) {
              if ($is_oper($1) == $true) {
                if (%this.item == $mIRCd.info(%this.usock,trueHost)) { var %this.trueHostMatch = 1 }
              }
              if (%this.item == $mIRCd.info(%this.usock,host)) { var %this.hostMatch = 1 }
            }
            if (i isin %this.field) {
              if ($is_modeSet(%this.usock,x).nick == $false) {
                if (%this.item == $sock(%this.usock).ip) { var %this.ipMatch = 1 }
              }
              if ($is_oper($1) == $true) {
                if (%this.item == $sock(%this.usock).ip) { var %this.ipMatch = 1 }
              }
            }
            ; *** OWN IDEA ***
            if (j isin %this.field) {
              if ($regex(%this.item,(=|>|<|>=|<|<=|!=)\d+) != 1) { continue }
              var %this.cmp = $_stripNumbers(%this.item), %this.dur = $_stripMatch(%this.item)
              if ($sock(%this.usock).to %this.cmp %this.dur) { var %this.onlineMatch = 1 }
            }
            ; *** END ***
            if (n isin %this.field) {
              if (%this.item == $mIRCd.info(%this.usock,nick)) { var %this.nickMatch = 1 }
            }
            if (r isin %this.field) {
              var %this.realName = $mIRCd.info(%this.usock,realName)
              if ((%this.item == %this.realName) || (%this.item == $strip(%this.realName))) { var %this.nameMatch = 1 }
            }
            if (u isin %this.field) {
              if ((%this.item == $mIRCd.info(%this.usock,ident)) || (%this.item == $mIRCd.info(%this.usock,user))) { var %this.userMatch = 1 }
            }
            if ((%this.operMatch != 1) && (%this.trueHostMatch != 1) && (%this.hostMatch != 1) && (%this.ipMatch != 1) && (%this.onlineMatch != 1) && (%this.nickMatch != 1) && (%this.nameMatch != 1) && (%this.userMatch != 1)) { continue }
          }
          var %this.saw = %this.usock, %this.reply = $mIRCd.whoString(%this.string,$1,%this.usock)
          mIRCd.sraw $1 $mIRCd.reply(%this.numeric,$mIRCd.info($1,nick),%this.reply)
          if (%this.flag != 1) { var %this.flag = 1 }
        }
        continue
      }
      if ($is_exists(%this.item).nick == $true) {
        if ((%this.nFlag == 1) && ($numtok(%this.who,44) == 1)) { continue }
        ; `-> Here's that specific flag check I mentioned before.
        var %this.usock = $getSockname(%this.item)
        if (($mIRCd.chanSeen(%this.chanSeen,%this.usock) > 0) && ($mIRCd.chanSeen(%this.secret,%this.usock) == 0) && ($istok(%this.invisible,%this.usock,32) == $false)) { continue }
        var %this.saw = %this.usock, %this.reply = $mIRCd.whoString(%this.string,$1,%this.usock)
        mIRCd.sraw $1 $mIRCd.reply(%this.numeric,$mIRCd.info($1,nick),%this.reply)
        if (%this.flag != 1) { var %this.flag = 1 }
        continue
      }
      continue
    }
    ; ,-> Someone specified a :search. (So the comma separated field gets ignored.)
    var %this.uloop = 0
    while (%this.uloop < $hcount($mIRCd.users)) {
      ; >-> 2048 / (number_of_fields + 4)
      var %this.operMatch = 0, %this.trueHostMatch = 0, %this.hostMatch = 0, %this.ipMatch = 0, %this.onlineMatch = 0, %this.nickMatch = 0, %this.nameMatch = 0, %this.userMatch = 0
      if (%this.saw != $null) { var %this.sockSeen = %this.sockSeen %this.saw, %this.saw = $null }
      inc %this.uloop 1
      var %this.usock = $hget($mIRCd.users,%this.uloop).item
      if ($istok(%this.sockSeen,%this.usock,32) == $true) { continue }
      if ($mIRCd.chanSeen(%this.chanSeen,%this.usock) > 0) { continue }
      if ($is_modeSet(%this.usock,i).nick == $true) {
        if (($1 != %this.usock) && ($is_mutual($1,%this.usock) == $false) && (%this.oper != 1)) { continue }
      }
      if (%this.field == $null) { continue }
      ; `-> Can't do anything without fields.
      var %this.search = $decolonize($5-)
      if (o isin %this.field) {
        if ($is_oper(%this.usock) == $false) { continue }
        var %this.operMatch = 1
      }
      if (h isin %this.field) {
        if ($is_oper($1) == $true) {
          var %this.trueHost = $mIRCd.info(%this.usock,trueHost)
          if ((%this.search == %this.trueHost) || (%this.search iswm %this.trueHost)) { var %this.trueHostMatch = 1 }
        }
        var %this.host = $mIRCd.info(%this.usock,host)
        if ((%this.search == %this.host) || (%this.search iswm %this.host)) { var %this.hostMatch = 1 }
      }
      if (i isin %this.field) {
        var %this.ip = $sock(%this.usock).ip
        if ($is_modeSet(%this.usock,x).nick == $false) {
          if ((%this.search == %this.ip) || (%this.search iswm %this.ip)) { var %this.ipMatch = 1 }
        }
        if ($is_oper($1) == $true) {
          if ((%this.search == %this.ip) || (%this.search iswm %this.ip)) { var %this.ipMatch = 1 }
        }
      }
      ; *** OWN IDEA ***
      if (j isin %this.field) {
        if ($regex(%this.search,(=|>|<|>=|<|<=|!=)\d+) != 1) { continue }
        var %this.cmp = $_stripNumbers(%this.search), %this.dur = $_stripMatch(%this.search)
        if ($sock(%this.usock).to %this.cmp %this.dur) { var %this.onlineMatch = 1 }
      }
      ; *** END ***
      if (n isin %this.field) {
        var %this.handle = $mIRCd.info(%this.usock,nick)
        ; `-> Just incase I've used %this.nick already...
        if ((%this.search == %this.handle) || (%this.search iswm %this.handle)) { var %this.nickMatch = 1 }
      }
      if (r isin %this.field) {
        var %this.realName = $mIRCd.info(%this.usock,realName)
        if ((%this.search == %this.realName) || (%this.search iswm %this.realName) || (%this.search == $strip(%this.realName)) || (%this.search iswm $strip(%this.realName))) { var %this.nameMatch = 1 }
      }
      if (u isin %this.field) {
        var %this.ident = $mIRCd.info(%this.usock,ident), %this.user = $mIRCd.info(%this.user)
        if ((%this.search == %this.ident) || (%this.search iswm %this.ident) || (%this.search == %this.user) || (%this.search iswm %this.user)) { var %this.userMatch = 1 }
      }
      if ((%this.operMatch != 1) && (%this.trueHostMatch != 1) && (%this.hostMatch != 1) && (%this.ipMatch != 1) && (%this.onlineMatch != 1) && (%this.nickMatch != 1) && (%this.nameMatch != 1) && (%this.userMatch != 1)) { continue }
      var %this.saw = %this.usock, %this.reply = $mIRCd.whoString(%this.string,$1,%this.usock)
      mIRCd.sraw $1 $mIRCd.reply(%this.numeric,$mIRCd.info($1,nick),%this.reply)
      if (%this.flag != $null) { var %this.flag = 1 }
      if (%this.breakFlag != 1) { var %this.breakFlag = 1, %this.mwho = $gettok(%this.search,1,32) }
    }
    if (%this.breakFlag == 1) { break }
  }
  ; ,-> Leftovers. E.g. Wildcard searches or wildcard searches after no data was returned.
  if (%this.flag == $null) {
    if (%this.wild != $null) {
      var %this.loop = 0, %this.breakFlag = 0, %this.search = $null
      while (%this.loop < $numtok(%this.wild,32)) {
        if (%this.breakFlag == 1) { break }
        ; `-> If someone does something like /WHO *Serv,Jigs* then if *Serv returns anything, we list those entries and end it. Jigs* etc. get skipped.
        var %this.operMatch = 0, %this.trueHostMatch = 0, %this.hostMatch = 0, %this.ipMatch = 0, %this.onlineMatch = 0, %this.nickMatch = 0, %this.nameMatch = 0, %this.userMatch = 0
        inc %this.loop 1
        var %this.item = $iif($gettok(%this.wild,%this.loop,32) != 0,$v1,*)
        var %this.uloop = 0
        while (%this.uloop < $hcount($mIRCd.users)) {
          ; >-> 2048 / (number_of_fields + 4)
          var %this.operMatch = 0, %this.trueHostMatch = 0, %this.hostMatch = 0, %this.ipMatch = 0, %this.onlineMatch = 0, %this.nickMatch = 0, %this.nameMatch = 0, %this.userMatch = 0
          if (%this.saw != $null) { var %this.sockSeen = %this.sockSeen %this.saw, %this.saw = $null }
          inc %this.uloop 1
          var %this.usock = $hget($mIRCd.users,%this.uloop).item
          if ($istok(%this.sockSeen,%this.usock,32) == $true) { continue }
          if ($mIRCd.chanSeen(%this.chanSeen,%this.usock) > 0) { continue }
          if ($is_modeSet(%this.usock,i).nick == $true) {
            if (($1 != %this.usock) && ($is_mutual($1,%this.usock) == $false) && (%this.oper != 1)) { continue }
          }
          var %this.search = $decolonize($5-)
          if (o isin %this.field) {
            if ($is_oper(%this.usock) == $false) { continue }
            var %this.operMatch = 1
          }
          ; ,-> I can't think of a way to do this which doesn't result in >>--Arrow--> code. ;_;
          if (h isin %this.field) {
            if ($is_oper($1) == $true) {
              var %this.trueHost = $mIRCd.info(%this.usock,trueHost)
              if (%this.item iswm %this.trueHost) {
                var %this.trueHostMatch = 1
                if (%this.search != $null) {
                  var %this.trueHostMatch = 0
                  if ((%this.search == %this.trueHost) || (%this.search iswm %this.trueHost)) { var %this.trueHostMatch = 1 }
                }
              }
            }
            var %this.host = $mIRCd.info(%this.usock,host)
            if (%this.item iswm %this.host) {
              var %this.hostMatch = 1
              if (%this.search != $null) {
                var %this.hostMatch = 0
                if ((%this.search == %this.host) || (%this.search iswm %this.host)) { var %this.hostMatch = 1 }
              }
            }
          }
          if (i isin %this.field) {
            var %this.ip = $sock(%this.usock).ip
            if ($is_modeSet(%this.usock,x).nick == $false) {
              if (%this.item iswm %this.ip) {
                var %this.ipMatch = 1
                if (%this.search != $null) {
                  var %this.ipMatch = 0
                  if ((%this.search == %this.ip) || (%this.search iswm %this.ip)) { var %this.ipMatch = 1 }
                }
              }
            }
            if (%this.ipMatch != 1) {
              if ($is_oper($1) == $true) {
                if (%this.item iswm %this.ip) {
                  var %this.ipMatch = 1
                  if (%this.search != $null) {
                    var %this.ipMatch = 0
                    if ((%this.search == %this.ip) || (%this.search iswm %this.ip)) { var %this.ipMatch = 1 }
                  }
                }
              }
            }
          }
          ; *** OWN IDEA ***
          if (j isin %this.field) {
            if ($regex(%this.search,(=|>|<|>=|<|<=|!=)\d+) != 1) { continue }
            var %this.cmp = $_stripNumbers(%this.search), %this.dur = $_stripMatch(%this.search)
            if ($sock(%this.usock).to %this.cmp %this.dur) { var %this.onlineMatch = 1 }
          }
          ; *** END ***
          if (n isin %this.field) {
            var %this.handle = $mIRCd.info(%this.usock,nick)
            if (%this.item iswm %this.handle) {
              var %this.nickMatch = 1
              if (%this.search != $null) {
                var %this.nickMatch = 0
                if ((%this.search == %this.handle) || (%this.search iswm %this.handle)) { var %this.nickMatch = 1 }
              }
            }
          }
          if (r isin %this.field) {
            var %this.realName = $mIRCd.info(%this.usock,realName)
            if ((%this.item iswm %this.realName) || (%this.item iswm $strip(%this.realName))) {
              var %this.nameMatch = 1
              if (%this.search != $null) {
                var %this.nameMatch = 0
                if ((%this.search == %this.realName) || (%this.search == $strip(%this.realName)) || (%this.search iswm %this.realName) || (%this.search iswm $strip(%this.realName))) { var %this.nameMatch = 1 }
              }
            }
          }
          if (u isin %this.field) {
            var %this.ident = $mIRCd.info(%this.usock,ident), %this.user = $mIRCd.info(%this.usock,user)
            if ((%this.item iswm %this.ident) || (%this.item iswm %this.user)) {
              var %this.userMatch = 1
              if (%this.search != $null) {
                var %this.userMatch = 0
                if ((%this.search == %this.ident) || (%this.search iswm %this.ident) || (%this.search == %this.user) || (%this.search iswm %this.user)) { var %this.userMatch = 1 }
              }
            }
          }
          if ((%this.operMatch != 1) && (%this.trueHostMatch != 1) && (%this.hostMatch != 1) && (%this.ipMatch != 1) && (%this.onlineMatch != 1) && (%this.nickMatch != 1) && (%this.nameMatch != 1) && (%this.userMatch != 1)) { continue }
          var %this.saw = %this.usock, %this.reply = $mIRCd.whoString(%this.string,$1,%this.usock)
          mIRCd.sraw $1 $mIRCd.reply(%this.numeric,$mIRCd.info($1,nick),%this.reply)
          if (%this.breakFlag != 1) { var %this.breakFlag = 1, %this.mwho = $gettok(%this.search,1,32) }
        }
      }
    }
  }
  mIRCd.sraw $1 $mIRCd.reply(315,$mIRCd.info($1,nick),$iif(%this.mwho != $null,$v1,$iif(%this.who != 0,$v1,*)))
  mIRCd.updateUser $1 whoTime $ctime
}
; ¦-> I'm not entirely proud of this code. I view it as incredibly inefficient. There has to be a better way of doing this...
; ¦-> Also, I'm not going to lie, this probably does have bugs in it.
; ¦
; `-> Also, further reading about WHOX: http://xise.nl/mirc/who.html

; Commands and Functions

alias mIRCd.chanSeen {
  ; $mIRCd.chanSeen(<%chanSeen string>,<sockname>)

  var %this.chanSeen = $1, %this.usock = $2
  return $count($regsubex($str(.,$numtok(%this.chanSeen,32)),/./g,$iif($istok($mIRCd.info(%this.usock,chans),$gettok(%this.chanSeen,\n,32),44) == $true,1,0)),1)
}
alias -l mIRCd.whoDefaults { return hnu }
alias mIRCd.lastJoined {
  ; $mIRCd.lastJoined(<sockname using /WHO>,<sockname being WHO'd>)

  var %this.id = $gettok($mIRCd.info($2,chans),1,44)
  if (%this.id == $null) { return * }
  if (($is_modeSet(%this.id,s).chan == $false) && ($is_modeSet($2,n).nick == $false)) { return $mIRCd.info(%this.id,name) }
  if (($1 == $2) || ($is_on(%this.id,$1) == $true) || ($is_oper($1) == $true)) { return $mIRCd.info(%this.id,name) }
  return *
}
alias mIRCd.whoFlags {
  ; $mIRCd.whoFlags(<sockname using /WHO>,<sockname being WHO'd>)

  if ($is_oper($1) == $true) { var %this.oper = 1 }
  var %this.chan = $mIRCd.lastJoined($1,$2), %this.chanStatus = $iif(%this.chan != *,$mIRCd.namesStatus($getChanID(%this.chan),$2))
  var %this.string = $+($iif($mIRCd.info($2,away) != $null,G,H),$iif($is_oper($2) == $true,*),$iif(%this.chanStatus != $null,$v1))
  if ($is_modeSet($2,d).nick == $true) { var %this.string = $+(%this.string,d) }
  var %this.modes = iwsg, %this.sock = $2
  var %this.string = $+(%this.string, $regsubex($str(.,$len(%this.modes)),/./g,$iif($is_modeSet(%this.sock,$mid(%this.modes,\n,1)).nick == $true && %this.oper == 1,$mid(%this.modes,\n,1))))
  if ($is_modeSet($2,x).nick == $true) { var %this.string = $+(%this.string,x) }
  return %this.string

}
alias mIRCd.whoIP {
  ; $mIRCd.whoIP(<sockname using /WHO>,<sockname being WHO'd>)

  if ($is_modeSet($2,x).nick == $false) { return $sock($2).ip }
  ; ,-> Note to self: Assuming +x is $true.
  if (($1 == $2) || ($is_oper($1) == $true)) { return $sock($2).ip }
  return $mIRCd.fakeIP
}
alias mIRCd.whoString {
  ; $mIRCd.whoString(<string>,<sockname using /WHO>,<sockname being WHO'd>)

  return $replace($1, <chan>, $mIRCd.lastJoined($2,$3), <user>, $iif($mIRCd.info($3,ident) != $null,$v1,$mIRCd.info($3,user)), <ip>, $mIRCd.whoIP($2,$3), <host>, $mIRCd.info($3,$iif($is_oper($2) == $true,trueHost,host)), <server>, $mIRCd(SERVER_NAME).temp, <nick>, $mIRCd.info($3,nick), <flags>, $mIRCd.whoFlags($2,$3), <idle>, $iif($mIRCd.info($3,idleTime) != $null,$calc($ctime - $v1),$sock($3).to), <account>, 0, <hopcount>, 0, <:hopcount>, :0, <realName>, $mIRCd.info($3,realName), <:realName>, $+(:,$mIRCd.info($3,realName)))
}

; EOF
