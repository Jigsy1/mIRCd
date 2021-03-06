; IRC /map demo - If you've ever done /map on a large IRC server, you will understand what this does.
; If you don't, see: https://i.imgur.com/jDaSHMa.png
;
; * To try it out, rename one of the files - 1.txt, 2.txt - to MAPS.txt and then do: /addMaps
; * To visualize the tree, do: /showMaps
; * To free the table, do: //hfree $mapTable
;
; Then try the other one to see the difference. You can also load maps up to a point. E.g. /addMaps 3
;
; If you wish to add more servers to MAPS.txt, it must be in the format of: child.server parent.server

alias addMaps {
  ; /addMaps [limit]

  if (($exists($mapFile) == $false) || ($lines($mapFile) == 0)) { return }
  var %this.loop = 0
  while (%this.loop < $iif($1 isnum 1-,$v1,$lines($mapFile))) {
    inc %this.loop 1
    hadd -m $mapTable $read($mapFile, n, %this.loop)
  }
}
alias showMaps {
  ; /showMaps

  var %this.main = towaherschel.localhost
  ; `-> This is our parent server. Everything else is a child.
  echo -at %this.main
  if ($hfind($mapTable,%this.main,0,W).data == 0) { goto map_End }
  var %this.loop = 0, %this.max = $hfind($mapTable,%this.main,0,W).data
  while (%this.loop < %this.max) {
    inc %this.loop 1
    var %this.server = $hfind($mapTable,%this.main,%this.loop,W).data, %this.count = $hfind($mapTable,%this.server,0,W).data
    var %this.pre = $iif(%this.count > 0,$iif(%this.loop != %this.max,$pipe,$tail),$iif(%this.loop != %this.max,$pipe,$tail)), %this.pos = $pos(%this.pre,$tail)
    ; `-> Note: Changed %this.loop <= %this.max to %this.loop != %this.max
    echo -at $+(%this.pre,-,%this.server)
    map_recurse 1 %this.count %this.server %this.pos
  }
  :map_End
  echo -at End of /MAP.
  return
}
alias -l map_recurse {
  ; /map_recurse <recursion number> <number of server's children> <server> <position-of-tail [position-of-tail ...]>

  var %this.recurse = $3, %this.pos = $4-
  if ($hfind($mapTable,%this.recurse,0,W).data == 0) { return }
  var %this.loop = 0, %this.max = $hfind($mapTable,%this.recurse,%this.loop,W).data
  while (%this.loop < %this.max) {
    inc %this.loop 1
    var %this.server = $hfind($mapTable,%this.recurse,%this.loop,W).data, %this.count = $hfind($mapTable,%this.server,0,W).data
    var %this.pre = $str($+($pipe,$chr(32)),$1) $+ $iif(%this.count > 0,$iif(%this.loop != $2,$pipe,$tail),$iif(%this.loop < %this.max,$pipe,$tail)), %this.pos = %this.pos $pos(%this.pre,$tail)
    var %this.pretty = $regsubex($str(.,$len(%this.pre)),/./g,$iif($istok(%this.pos,\n,32) == $false,$mid(%this.pre,\n,1),$iif($mid(%this.pre,\n,1) != $tail,$chr(160),$tail)))
    ; `-> Remove any branches that lead to nowhere.
    echo -at $+(%this.pretty,-,%this.server)
    .signal -n map_recurse $calc($1 + 1) %this.count %this.server %this.pos
    ; `-> Try replacing .signal -n map_recurse with recurse_map and adding the alias below?
  }
  return
}
on *:signal:map_recurse:{ map_recurse $1- }
; ¦-> Due to a change preventing direct recursion in mIRC 7.33, this *is* required.
; `-> That said adding the following would have probably worked too: alias recurse_map { map_recurse $1- }

; "Constants"

alias -l mapFile { return $qt($scriptdirMAPS.txt) }
alias mapTable { return mapTest }
alias -l pipe { return ¦ }
alias -l tail { return ` }
