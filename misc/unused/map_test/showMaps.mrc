; IRC /map demo - If you've ever done /map on a large IRC server, you will understand what this does.
; If you don't, see: https://i.imgur.com/jDaSHMa.png
;
; * To try it out, rename one of the files - 1.txt, 2.txt, etc. - to MAPS.txt and then do: /addMaps
; * To visualize the tree, do: /showMaps
; * If you want to visualize the three from a specific point, do: /showMaps server
; * To reverse lookup the original parent server, do: //echo -a $reverse_parent_search(server)
; * To free the table, do: //hfree $mapTable
;
; Then try the other one to see the difference.
;
; * You can also view the map from a certain point. E.g. /showMaps server.name
; * You can also load maps up to a point. E.g. /addMaps 3
;
; If you wish to add more servers to MAPS.txt, it must be in the format of: child.server parent.server

on *:unload:{
  if ($hget($mapTable)) { hfree $v1 }
}

; Core:

alias addMaps {
  ; /addMaps [limit]

  if ($hget($mapTable) != $null) { hfree $v1 }
  if ($lines($mapFile) == 0) { return }
  var %this.loop = 0
  while (%this.loop < $iif($1 isnum 1-,$v1,$lines($mapFile))) {
    inc %this.loop 1
    hadd -m $mapTable $read($mapFile, n, %this.loop)
  }
}
alias showMaps {
  ; /showMaps [server]

  var %this.parent = $iif($1 != $null,$v1,$parent_server)
  ; `-> This is our parent server. Everything else is a child and progeny.
  echo -at %this.parent
  if ($hfind($mapTable,%this.parent,0,W).data == 0) {
    echo -at $end_of_map
    return
  }
  map_recurse 0 $hfind($mapTable,%this.parent,0,W).data %this.parent
  echo -at $end_of_map
  return
}
alias -l map_recurse {
  ; /map_recurse <recursion number> <number of progeny> <server.name> [position-of-tail [position-of-tail ...]]

  var %this.pos = $4-
  if ($hfind($mapTable,$3,0,W).data == 0) { return }
  var %this.loop = 0, %this.max = $hfind($mapTable,$3,0,W).data
  while (%this.loop < %this.max) {
    inc %this.loop 1
    var %this.child = $hfind($mapTable,$3,%this.loop,W).data, %this.count = $hfind($mapTable,%this.child,0,W).data
    var %this.pre = $str($+($pipe,$chr(32)),$1) $+ $iif(%this.count > 0,$iif(%this.loop != $2,$pipe,$tail),$iif(%this.loop < %this.max,$pipe,$tail)), %this.pos = %this.pos $pos(%this.pre,$tail)
    var %this.pretty = $regsubex($str(.,$len(%this.pre)),/./g,$iif($istok(%this.pos,\n,32) == $false,$mid(%this.pre,\n,1),$iif($mid(%this.pre,\n,1) != $tail,$chr(160),$tail)))
    ; `-> Remove any branches that lead to nowhere.
    echo -at $+(%this.pretty,$branch,%this.child)
    recurse_map $calc($1 + 1) %this.count %this.child %this.pos
  }
  return
}
alias recurse_map { map_recurse $1- }
; `-> Due to a change preventing direct recursion in mIRC 7.33, this *is* required.
alias reverse_parent_search {
  ; $reverse_parent_search(<server>)
  ;
  ; Find the original parent in the chain that the server descended from.
  ;
  ; <our server>
  ; ¦-<original parent>
  ; ¦ ¦-... ...
  ; ... ... ...
  ; ... ... `-<start>
  ; ...

  var %this.break = $parent_server
  ; `-> We end right before this one.
  if ($hget($mapTable,$1) == $null) { return }
  var %this.search = $1
  while (%this.search != %this.break) {
    var %this.parent = $hget($mapTable,%this.search)
    if (%this.parent == %this.break) { break }
    if (%this.parent == $null) { return }
    ; `-> Something went wrong.
    var %this.search = %this.parent
  }
  return %this.search
}
alias reverse_chain_search {
  ; $reverse_chain_search(<server>,<possible parent>[,hops])
  ;
  ; Find out if a server is in fact above a server in the chain.
  ;
  ; E.g. A->B->C->D->E
  ;
  ; 1. D is above E
  ; 2. C is above E
  ; 3. E is not above D, C, etc.

  if ($hget($mapTable,$1) == $null) { return }
  if ($hget($mapTable,$2) == $null) { return }
  if ($3 isnum 1-) { var %this.loop = 0 }
  var %this.break = $2, %this.search = $1
  while (%this.search != %this.break) {
    if (($3 isnum 1-) && (%this.loop == $3)) { break }
    var %this.parent = $hget($mapTable,%this.search)
    if (%this.parent == %this.break) { return %this.break }
    if (%this.parent == $null) { return }
    var %this.search = %this.parent
    if ($3 isnum 1-) { inc %this.loop 1 }
  }
  return %this.search
}

; "Constants"

alias -l branch { return - }
alias -l end_of_map { return End of /MAP }
alias -l mapFile { return $qt($scriptdirMAPS.txt) }
alias mapTable { return mapTest }
alias -l parent_server { return towaherschel.localhost }
alias -l pipe { return ¦ }
alias -l tail { return ` }

; EOF
