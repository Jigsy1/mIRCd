; debugUser.mrc
;
; Simple socket user for debugging purposes. Connect via: /sockopen debugUser <server ip> <server port>

menu Menubar {
  .&Debug User
  ..$iif($window($debugUser.window) != $null,$style(2)) Information Window:{ window -ek0n $debugUser.window }
}
on *:sockclose:debugUser:{
  if ($window($debugUser.window) != $null) { echo -ci2t "Info text" $v1 [C]: $sockname closed }
}
on *:sockopen:debugUser:{
  if ($sockerr == 0) {
    debugUser.raw NICK $debugUser.nick
    debugUser.raw USER $debugUser.nick 0 0 $+(:4D7,$str(e,7),8b9,$str(u,7),10gg11,$str(e,7),13r15,$str(!,7))
    return
  }
  if ($window($debugUser.window) != $null) { echo -ci2t "Info text" $v1 [E]: $sockname error }
}
on *:sockread:debugUser:{
  var %debugUser.sockRead = $null
  sockread %debugUser.sockRead
  tokenize 32 %debugUser.sockRead

  if ($sockerr > 0) {
    if ($window($debugUser.window) != $null) { echo -ci2t "Info text" $v1 [E]: $sockname error }
    return
  }
  if ($window($debugUser.window) != $null) { echo -ci2t "Info text" $v1 [R]: $sockname <- $1- }
  if ($1 == PING) { debugUser.raw PONG $2- }
}

; Commands and Functions

alias -l debugUser.nick { return Debugger }
alias debugUser.raw {
  ; /debugUser.raw <args>

  if ($window($debugUser.window) != $null) { echo -ci2t "Info text" $v1 [W]: debugUser -> $1- }
  if ($sock(debugUser) != $null) { sockwrite -nt debugUser $1- }
}
alias -l debugUser.window { return @debugUser }

; EOF
