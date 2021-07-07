; mIRCd_modeParse_v0.mrc
;
; I didn't want to completely remove this, so here it is in the backup folder. It's trumped by the newer, less sucky version.

#mIRCd.mode off
alias -l mIRCd.parseMode {
  ; /mIRCd.parseMode <args>

  if ($3 != $null) {
    if ($is_valid($3).chan == $true) {
      if ($4- != $null) {
        if ($mIRCd.chanExists($3) == $true) {
          var %this.id = $getChanID($3)
          if ($2 == OPMODE) { goto mIRCd_parse_mode_process }
          if ($mIRCd.onChan($3,$1) == $true) {
            if (($is_modeSet($1,X).nick == $true) || ($is_op(%this.id,$1) == $true) || ($is_hop(%this.id,$1) == $true) || (%this.status == 1)) {
              var %this.status = $iif($is_op(%this.id,$1) == $true,1,$iif($is_modeSet($1,X).nick == $true,1,0)) $iif($is_hop(%this.id,$1) == $true,1,0)
              ; `-> Register them as having status. (Incase they deop themselves in the process, or something.)
              :mIRCd_parse_mode_process
              var %this.flag = $null, %this.minus = -, %this.plus = +, %this.arg = 0, %this.argMinus = $null, %this.argPlus = $null
              var %mIRCd.modeNumber = 0
              while (%mIRCd.modeNumber < $len($4)) {
                inc %mIRCd.modeNumber 1
                var %this.char = $mid($4,%mIRCd.modeNumber,1)
                if (%this.flag == $null) {
                  if ($pos(-+,%this.char) != $null) { var %this.flag = %this.char }
                }
                else {
                  if ($pos(-+,%this.char) != $null) { var %this.flag = %this.char }
                  else {
                    if (%this.flag == -) {
                      if ($poscs(OP,%this.char) != $null) {
                        if ($is_oper($1) == $true) {
                          if ($is_modeSet(%this.id,%this.char).chan == $true) {
                            mIRCd.updateChan %this.id modes $removecs($mIRCd.info(%this.id,modes),%this.char)
                            var %this.minus = $+(%this.minus,%this.char)
                            if (%this.char isincs %this.plus) { var %this.plus = $removecs(%this.plus,%this.char) }
                          }
                        }
                        else { mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick)) }
                      }
                      ; elseif (%this.char === b) { }
                      elseif (%this.char === g) {
                        if ($is_modeSet(%this.id,%this.char).chan == $true) {
                          mIRCd.updateChan %this.id modes $+($mIRCd.info(%this.id,modes),%this.char)
                          var %this.minus $+(%this.minus,%this.char)
                          if (%this.char isincs %this.plus) {
                            var %this.plus = $removecs(%this.plus,%this.char)
                            var %this.argPlus = $remtokcs(%this.argPlus,$+(%this.char,:,$mIRCd.info(%this.id,gagTime)),1,32)
                          }
                          mIRCd.delChanItem %this.id gagTime
                        }
                      }
                      elseif ($poscs(hov,%this.char) != $null) {
                        inc %this.arg 1
                        var %this.token = $gettok($5-,%this.arg,32)
                        if (%this.token != $null) {
                          if ($getSockname(%this.token) != $null) {
                            var %this.sock = $v1
                            if ($mIRCd.onChan($3,%this.sock) == $true) {
                              if (($gettok(%this.status,1,32) == 0) && ($poscs(ho,%this.char) != $null)) {
                                ; `-> Hops should not be able to +/-ho
                                mIRCd.sraw $1 $mIRCd.reply(482,$mIRCd.info($1,nick),$3)
                                goto mIRCd_parse_hop_minus
                              }
                              if ($is_chanStatus(%this.id,%this.sock,%this.char) == $true) {
                                if ((%this.char === o) && ($is_modeSet(%this.sock,k).nick == $true)) {
                                  if ($2 == OPMODE) { goto mIRCd_parse_opmode }
                                  else { mIRCd.sraw $1 $mIRCd.reply(484,$mIRCd.info($1,nick),$3,%this.token) }
                                }
                                ; `-> 484 is for +k'd user(s). In the case of a Service (E.g. ChanServ) connecting via a C:lined services server, it's 485.
                                else {
                                  :mIRCd_parse_opmode
                                  mIRCd.updateChanUser %this.id %this.sock 0 $calc($poscs(ohv,%this.char) + 2)
                                  var %this.minus = $+(%this.minus,%this.char)
                                  var %this.minusToken = $+(%this.char,:,%this.token)
                                  var %this.argMinus = %this.argMinus %this.minusToken
                                  if ($istokcs(%this.argPlus,%this.minusToken,32) == $true) {
                                    var %this.argPlus = $remtokcs(%this.argPlus,%this.minusToken,1,32)
                                    var %this.plus = $remove($remtokcs($regsubex(%this.plus,/(.)/g,$+(\t,.)),%this.char,1,46),.)
                                  }
                                  ; `-> Hopefully this won't cause any issues. E.g. +ohv Jigsy Jigsy Jigsy, +vvv Jigsy Jigsy Jigsy, +v-v+v-v+h Jigsy Jigsy Jigsy Jigsy Jigsy, +ohvvvv Jigsy, etc.
                                  :mIRCd_parse_hop_minus
                                }
                              }
                            }
                            else { mIRCd.sraw $1 $mIRCd.reply(441,$mIRCd.info($1,nick),%this.token,$3) }
                          }
                          else { mIRCd.sraw $1 $mIRCd.reply(401,$mIRCd.info($1,nick),%this.token) }
                        }
                      }
                      elseif (%this.char === k) {
                        inc %this.arg 1
                        var %this.token = $gettok($5-,%this.arg,32)
                        if (%this.token != $null) {
                          if ($is_modeSet(%this.id,%this.char).chan == $true) {
                            if (%this.token === $mIRCd.info(%this.id,key)) {
                              var %this.lastKey = $+(%this.char,:,$v2)
                              mIRCd.updateChan %this.id modes $removecs($mIRCd.info(%this.id,modes),%this.char)
                              var %this.minus = $+(%this.minus,%this.char)
                              var %this.minusToken = $+(%this.char,:,%this.token)
                              var %this.argMinus = %this.argMinus %this.minusToken
                              if (%this.char isincs %this.plus) {
                                var %this.plus = $removecs(%this.plus,%this.char)
                                var %this.argPlus = $remtok(%this.argPlus,%this.minusToken,1,32)
                              }
                              mIRCd.delChanItem %this.id key
                            }
                            else { mIRCd.sraw $1 $mIRCd.reply(467,$mIRCd.info($1,nick),$3) }
                          }
                        }
                        else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2,$+(%this.flag,%this.char)) }
                      }
                      elseif (%this.char === l) {
                        ; `-> Do not check for tokens. Complain about the nick not existing = normal.
                        if ($is_modeSet(%this.id,%this.char).chan == $true) {
                          mIRCd.updateChan %this.id modes $removecs($mIRCd.info(%this.id,modes),%this.char)
                          var %this.minus = $+(%this.minus,%this.char)
                          if (%this.char isincs %this.plus) {
                            var %this.plus = $removecs(%this.plus,%this.char)
                            var %this.argPlus = $remtokcs(%this.argPlus,$+(%this.char,:,$mIRCd.info(%this.id,limit)),1,32)
                          }
                          mIRCd.delChanItem %this.id limit
                        }
                      }
                      elseif ($poscs(imnpstCNSKT,%this.char) != $null) {
                        if ($is_modeSet(%this.id,%this.char).chan == $true) {
                          mIRCd.updateChan %this.id modes $removecs($mIRCd.info(%this.id,modes),%this.char)
                          var %this.minus = $+(%this.minus,%this.char)
                          if (%this.char isincs %this.plus) { var %this.plus = $removecs(%this.plus,%this.char) }
                        }
                      }
                      else { mIRCd.sraw $1 $mIRCd.reply(501,$mIRCd.info($1,nick),%this.char) }
                    }
                    else {
                      ; `-> + mode(s).
                      if ($poscs(OP,%this.char) != $null) {
                        if ($is_oper($1) == $true) {
                          if ($is_modeSet(%this.id,%this.char).chan == $false) {
                            mIRCd.updateChan %this.id modes $+($mIRCd.info(%this.id,modes),%this.char)
                            var %this.plus = $+(%this.plus,%this.char)
                            if (%this.char isincs %this.minus) { var %this.minus = $removecs(%this.minus,%this.char) }
                          }
                        }
                        else { mIRCd.sraw $1 $mIRCd.reply(481,$mIRCd.info($1,nick)) }
                      }
                      ; elseif (%this.char === b) { }
                      elseif (%this.char === g) {
                        ; `-> Don't include the parameter in the argMinus string if removing it. It isn't needed.
                      }
                      elseif ($poscs(hov,%this.char) != $null) {
                        ; `-> TODO: Hops cannot -oh/+oh.
                        inc %this.arg 1
                        var %this.token = $gettok($5-,%this.arg,32)
                        if (%this.token != $null) {
                          if ($getSockname(%this.token) != $null) {
                            var %this.sock = $v1
                            if ($mIRCd.onChan($3,%this.sock) == $true) {
                              if (($gettok(%this.status,1,32) == 0) && ($poscs(ho,%this.char) != $null)) {
                                ; `-> Hops should not be able to +/-ho
                                mIRCd.sraw $1 $mIRCd.reply(482,$mIRCd.info($1,nick),$3)
                                goto mIRCd_parse_hop_plus
                              }
                              if ($is_chanStatus(%this.id,%this.sock,%this.char) == $false) {
                                mIRCd.updateChanUser %this.id %this.sock 1 $calc($poscs(ohv,%this.char) + 2)
                                var %this.plus = $+(%this.plus,%this.char)
                                var %this.plusToken = $+(%this.char,:,%this.token)
                                var %this.argPlus = %this.argPlus %this.plusToken
                                if ($istokcs(%this.argMinus,%this.plusToken,32) == $true) {
                                  var %this.argMinus = $remtokcs(%this.argMinus,%this.plusToken,1,32)
                                  var %this.minus = $remove($remtokcs($regsubex(%this.minus,/(.)/g,$+(\t,.)),%this.char,1,46),.)
                                }
                                :mIRCd_parse_hop_plus
                                ; `-> Ditto.
                              }
                            }
                            else { mIRCd.sraw $1 $mIRCd.reply(441,$mIRCd.info($1,nick),%this.token,$3) }
                          }
                          else { mIRCd.sraw $1 $mIRCd.reply(401,$mIRCd.info($1,nick),%this.token) }
                        }
                        ; `-> If the arg doesn't exist, it doesn't tell you. (Unlike +k and +l.)
                      }
                      elseif (%this.char === k) {
                        inc %this.arg 1
                        var %this.token = $gettok($5-,%this.arg,32)
                        if (%this.token != $null) {
                          if ($is_valid(%this.token).key == $true) {
                            var %this.key = $left($cleanKey(%this.token),$mIRCd(KEYLEN))
                            ; `-> I'm not sure what keys are allowed to contain, but I do know they cannot start with :, so clean it up.
                            if (%this.key != $null) {
                              if ($is_modeSet(%this.id,%this.char).chan == $false) {
                                mIRCd.updateChan %this.id modes $+($mIRCd.info(%this.id,modes),%this.char)
                                var %this.plus = $+(%this.plus,%this.char)
                                var %this.plusToken = $+(%this.char,:,%this.key)
                                var %this.argPlus = %this.argPlus %this.plusToken
                                if (%this.char isincs %this.minus) {
                                  var %this.minus = $removecs(%this.minus,%this.char)
                                  var %this.argMinus = $remtokcs(%this.argMinus,%this.lastKey,1,32)
                                }
                                mIRCd.updateChan %this.id key %this.key
                              }
                              else { mIRCd.sraw $1 $mIRCd.reply(467,$mIRCd.info($1,nick),$3) }
                            }
                            else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2,$+(%this.flag,%this.char)) }
                          }
                          else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2,$+(%this.flag,%this.char)) }
                          ; `-> Wrong numeric?
                        }
                        else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2,$+(%this.flag,%this.char)) }
                      }
                      elseif (%this.char === l) {
                        ; `-> Don't include the parameter in the argMinus string if removing it. It isn't needed.
                        inc %this.arg 1
                        var %this.token = $gettok($5-,%this.arg,32)
                        if (%this.token != $null) {
                          if (%this.token isnum 1-) {
                            if ($is_modeSet(%this.id,%this.char).chan == $false) {
                              mIRCd.updateChan %this.id modes $+($mIRCd.info(%this.id,modes),%this.char)
                              var %this.plus = $+(%this.plus,%this.char)
                              var %this.plusToken = $+(%this.char,:,%this.token)
                              var %this.argPlus = %this.argPlus %this.plusToken
                              if (%this.char isincs %this.minus) { var %this.minus = $removecs(%this.minus,%this.char) }
                              mIRCd.updateChan %this.id limit %this.token
                            }
                            else {
                              ; `-> Update the number.
                              if (%this.token != $mIRCd.info(%this.id,limit)) {
                                if (%this.char !isincs %this.plus) {
                                  var %this.plus = $+(%this.plus,%this.char)
                                  var %this.plusToken = $+(%this.char,:,%this.token)
                                  var %this.argPlus = %this.argPlus %this.plusToken
                                }
                                if (%this.char isincs %this.minus) { var %this.minus = $removecs(%this.minus,%this.char) }
                                mIRCd.updateChan %this.id limit $gettok(%this.plusToken,2,58)
                                ; `-> If someone does +lll 21 69 1337, it will set 21 as the limit.
                              }
                            }
                          }
                          else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2,$+(%this.flag,%this.char)) }
                        }
                        else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2,$+(%this.flag,%this.char)) }
                      }
                      elseif ($poscs(ps,%this.char) != $null) {
                        if ($is_modeSet(%this.id,%this.char).chan == $false) {
                          mIRCd.updateChan %this.id modes $+($mIRCd.info(%this.id,modes),%this.char)
                          var %this.plus = $+(%this.plus,%this.char)
                          if (%this.char isincs %this.minus) { var %this.minus = $removecs(%this.minus,%this.char) }
                          var %this.polar = $iif(%this.char === p,s,p)
                          ; `-> Make sure the polar opposite isn't set. +p cannot be set as well as +s. It's one or the other.
                          if ($is_modeSet(%this.id,%this.polar).chan == $true) {
                            mIRCd.updateChan %this.id modes $removecs($mIRCd.info(%this.id,modes),%this.polar)
                            var %this.minus = $+(%this.minus,%this.polar)
                            if (%this.polar isincs %this.plus) { var %this.plus = $removecs(%this.plus,%this.polar) }
                          }
                        }
                      }
                      elseif ($poscs(imntCNKST,%this.char) != $null) {
                        if ($is_modeSet(%this.id,%this.char).chan == $false) {
                          mIRCd.updateChan %this.id modes $+($mIRCd.info(%this.id,modes),%this.char)
                          var %this.plus = $+(%this.plus,%this.char)
                          if (%this.char isincs %this.minus) { var %this.minus = $removecs(%this.minus,%this.char) }
                        }
                      }
                      else { mIRCd.sraw $1 $mIRCd.reply(472,$mIRCd.info($1,nick),%this.char) }
                    }
                  }
                }
                if ($calc(($len(%this.minus) + $len(%this.plus)) - 2) >= $mIRCd(MODESPL)) {
                  if (%this.plus != +) { var %this.string = $v1 }
                  if (%this.minus != -) { var %this.string = $+(%this.string,$v1) }
                  if (%this.argPlus != $null) { var %this.string = %this.string $regsubex($str(.,$numtok($v1,32)),/./g,$+($gettok($gettok($v1,\n,32),2-,58),$chr(32))) }
                  if (%this.argMinus != $null) { var %this.string = %this.string $regsubex($str(.,$numtok($v1,32)),/./g,$+($gettok($gettok($v1,\n,32),2-,58),$chr(32))) }
                  ; `-> Using $space instead of $chr(32) didn't work.
                  var %mIRCd.userNumber = 0
                  while (%mIRCd.userNumber < $hcount($mIRCd.chanUsers(%this.id))) {
                    inc %mIRCd.userNumber 1
                    var %this.sock = $hget($mIRCd.chanUsers(%this.id),%mIRCd.userNumber).item
                    mIRCd.raw %this.sock $colonize($iif($2 == OPMODE,$hget($mIRCd.temp,SERVER_NAME),$mIRCd.fulladdr($1))) MODE $3 %this.string
                  }
                  var %this.minus = -, %this.plus = +, %this.argMinus = $null, %this.argPlus = $null, %this.string = $null
                }
              }
              if ($calc($len(%this.minus) + $len(%this.plus)) > 2) {
                if (%this.plus != +) { var %this.string = $v1 }
                if (%this.minus != -) { var %this.string = $+(%this.string,$v1) }
                if (%this.argPlus != $null) { var %this.string = %this.string $regsubex($str(.,$numtok($v1,32)),/./g,$+($gettok($gettok($v1,\n,32),2-,58),$chr(32))) }
                if (%this.argMinus != $null) { var %this.string = %this.string $regsubex($str(.,$numtok($v1,32)),/./g,$+($gettok($gettok($v1,\n,32),2-,58),$chr(32))) }
                ; `-> Ditto.
                var %mIRCd.userNumber = 0
                while (%mIRCd.userNumber < $hcount($mIRCd.chanUsers(%this.id))) {
                  inc %mIRCd.userNumber 1
                  var %this.sock = $hget($mIRCd.chanUsers(%this.id),%mIRCd.userNumber).item
                  mIRCd.raw %this.sock $colonize($iif($2 == OPMODE,$hget($mIRCd.temp,SERVER_NAME),$mIRCd.fulladdr($1))) MODE $3 %this.string
                }
              }
            }
            else { mIRCd.sraw $1 $mIRCd.reply(482,$mIRCd.info($1,nick),$3) }
          }
          else { mIRCd.sraw $1 $mIRCd.reply(442,$mIRCd.info($1,nick),$3) }
        }
        else { mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),$3) }
      }
      else {
        if ($2 != OPMODE) {
          if ($mIRCd.chanExists($3) == $true) {
            var %this.id = $getChanID($3)
            var %this.posK = 0, %this.posL = 0
            /*
            if ($is_modeSet(%this.id,g).chan == $true) {
              var %this.posG = $poscs($mIRCd.info(%this.id,modes),g)
              var %this.gag = $mIRCd.info(%this.id,gagTime)
            }
            */
            if ($is_modeSet(%this.id,k).chan == $true) {
              var %this.posK = $poscs($mIRCd.info(%this.id,modes),k)
              var %this.key = $mIRCd.info(%this.id,key)
            }
            if ($is_modeSet(%this.id,l).chan == $true) {
              var %this.posL = $poscs($mIRCd.info(%this.id,modes),l)
              var %this.limit = $mIRCd.info(%this.id,limit)
            }
            ; if (%this.posG > 0) { var %this.arg0 = %this.gag }
            if (%this.posK > 0) { var %this.arg1 = %this.key }
            if (%this.posL > 0) { var %this.arg2 = %this.limit }
            if (%this.posK > %this.posL) { var %this.arg1 = %this.limit, %this.arg2 = %this.key }

            if ($mIRCd.onChan($3,$1) == $true) {
              mIRCd.sraw $1 $mIRCd.reply(324,$mIRCd.info($1,nick),$3,$mIRCd.info(%this.id,modes),%this.arg1,%this.arg2)
              mIRCd.sraw $1 $mIRCd.reply(329,$mIRCd.info($1,nick),$3,$mIRCd.info(%this.id,createTime))
            }
            else {
              ; `-> +p? +s?
            }          
          }
          else { mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),$3) }
        }
        else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2) }
      }
    }
    else {
      ; `-> A user. However, we can't change modes for other users. (Opers can view the modes of others, though.)
      if ($2 != OPMODE) {
        ; `-> Can't change usermodes via /OPMODE.
        if ($3 == $mIRCd.info($1,nick)) {
          if ($4 != $null) {
            var %this.flag = $null, %this.minus = -, %this.plus = +
            var %mIRCd.modeNumber = 0
            while (%mIRCd.modeNumber < $len($4)) {
              inc %mIRCd.modeNumber 1
              var %this.char = $mid($4,%mIRCd.modeNumber,1)
              if (%this.flag == $null) {
                if ($pos(-+,%this.char) != $null) { var %this.flag = %this.char }
              }
              else {
                if ($pos(-+,%this.char) != $null) { var %this.flag = %this.char }
                else {
                  if (%this.flag == -) {
                    if ($poscs(dgiknoswCDISWX,%this.char) != $null) {
                      if ($is_modeSet($1,%this.char).nick == $true) {
                        mIRCd.updateUser $1 modes $removecs($mIRCd.info($1,modes),%this.char)
                        var %this.minus = $+(%this.minus,%this.char)
                        if (%this.char isincs %this.plus) { var %this.plus = $removecs(%this.plus,%this.char) }
                        if ($poscs(io,%this.char) != $null) { hdel $iif(%this.char === i,$mIRCd.invisible,$mIRCd.opersOnline) $1 }
                        ; `-> This is a very hacky way of fiddling with the LUSERS numbers.
                      }
                    }
                    else {
                      if (%this.char !=== x) { mIRCd.sraw $1 $mIRCd.reply(501,$mIRCd.info($1,nick),%this.char) }
                      ; `-> +x can never be unset once set. But, we don't want it returning "no such mode," either.
                    }
                  }
                  else {
                    ; `-> + mode(s).
                    if ($poscs(gkWX,%this.char) != $null) {
                      if ($is_oper($1) == $true) {
                        if ($is_modeSet($1,%this.char).nick == $false) {
                          mIRCd.updateUser $1 modes $+($mIRCd.info($1,modes),%this.char)
                          var %this.plus = $+(%this.plus,%this.char)
                          if (%this.char isincs %this.minus) { var %this.minus = $removecs(%this.minus,%this.char) }
                          ; if ($poscs(kX,%this.char) != $null) { mIRCd.serverWallops Oper $parenthesis($gettok($mIRCd.fulladdr($1),2-,33)) has set mode: $+(+,%this.char) }
                        }
                      }
                      ; `-> Don't tell the user. (There's no rule saying you can't, though.)
                    }
                    elseif ($poscs(dinswxCDIS,%this.char) != $null) {
                      if ($is_modeSet($1,%this.char).nick == $false) {
                        mIRCd.updateUser $1 modes $+($mIRCd.info($1,modes),%this.char)
                        var %this.plus = $+(%this.plus,%this.char)
                        if (%this.char isincs %this.minus) { var %this.minus = $removecs(%this.minus,%this.char) }
                        if (%this.char === i) { hadd -m $mIRCd.invisible $1 $ctime }
                        ; `-> Ditto.
                        if (%this.char === x) {
                          ; `-> Obfuscate the host.
                        }
                      }
                      else {
                        ; `-> +s only for SNOMASK.
                      }
                    }
                    else {
                      if (%this.char !== o) { mIRCd.sraw $1 $mIRCd.reply(501,$mIRCd.info($1,nick),%this.char) }
                      ; `-> +o can never be set via /mode. But, we don't want it returning "no such mode," either.
                    }
                  }
                }
              }
            }
            if ($calc($len(%this.minus) + $len(%this.plus)) > 2) {
              if (%this.plus != +) { var %this.string = $v1 }
              if (%this.minus != -) { var %this.string = $+(%this.string,$v1) }
              mIRCd.raw $1 $colonize($mIRCd.fulladdr($1)) MODE $3 $colonize(%this.string)
            }
            ; `-> Interestingly, MODESPL doesn't matter for usermode(s). Also, this is the only MODE which is colonized.
          }
          else { mIRCd.sraw $1 $mIRCd.reply(221,$mIRCd.info($1,nick),$mIRCd.info($1,modes)) }
        }
        else {
          if ($is_oper($1) == $true) {
            if ($mIRCd.nickExists($3) == $true) {
              if ($4- == $null) { mIRCd.sraw $1 $mIRCd.reply(221,$3,$mIRCd.info($getSockname($3),modes)) }
              else { mIRCd.sraw $1 $mIRCd.reply(502,$mIRCd.info($1,nick)) }
            }
            else { mIRCd.sraw $1 $mIRCd.reply(401,$mIRCd.info($1,nick),$3) }
          }
          else { mIRCd.sraw $1 $mIRCd.reply(502,$mIRCd.info($1,nick)) }
        }
      }
      else { mIRCd.sraw $1 $mIRCd.reply(403,$mIRCd.info($1,nick),$3) }
    }
  }
  else { mIRCd.sraw $1 $mIRCd.reply(461,$mIRCd.info($1,nick),$2) }
}
; `-> I've decided to point MODE and OPMODE (checking which is which) into one alias because of how fucking huge of a task parsing is.
#mIRCd.mode end
