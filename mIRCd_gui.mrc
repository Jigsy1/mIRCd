; mIRCd_gui.mrc
;
; Note: I honestly don't use dialogs in mIRC. I prefer the command line approach to life. But this is for your benefit, not mine.

dialog mIRCd {
  title "mIRCd - [/mIRCd.gui]"
  size -1 -1 89 96
  option dbu

  box "", 1, 3 0 84 68
  button "&LOAD", 2, 6 4 77 10
  button "&START", 3, 6 17 77 9
  box "", 4, 3 26 84 4
  button "&DIE", 5, 6 32 77 9
  button "RE&HASH", 6, 6 44 77 9
  button "&RESTART", 7, 6 55 77 9
  edit "", 8, 3 69 84 8, disable
  button "&Close", 9, 49 84 37 9, default ok
}
on *:dialog:mIRCd:*:*:{
  if ($devent == close) {
    if ($timer($mIRCd.guiTimer) != $null) { $+(.timer,$mIRCd.guiTimer) off }
  }
  if ($devent == init) {
    if ($sock(mIRCd.*,0) > 0) { did -o $dname 3 1 &START (already running) }
    if ($hget($mIRCd.temp,startTime) != $null) {
      $+(.timer,$mIRCd.guiTimer) -o 0 1 mIRCd.updateUptime
    }
    else { did -o $dname 8 1 Uptime: N/A }
  }
  if ($devent == sclick) {
    if ($did == 2) { mIRCd.load }
    if ($did == 3) {
      mIRCd.start
      if ($sock(mIRCd.*,0) > 0) { did -o $dname 3 1 &START (running) }
      if ($hget($mIRCd.temp,startTime) != $null) {
        if ($timer($mIRCd.guiTimer) == $null) { $+(.timer,$mIRCd.guiTimer) -o 0 1 mIRCd.updateUptime }
      }
    }
    if ($did == 5) {
      mIRCd.die
      if ($sock(mIRCd.*,0) == 0) { did -o $dname 3 1 &START }
      if ($timer($mIRCd.guiTimer) != $null) { $+(.timer,$mIRCd.guiTimer) off }
      did -o $dname 8 1 N/A
    }
    if ($did == 6) { mIRCd.rehash }
    if ($did == 7) { mIRCd.restart }
  }
}
alias mIRCd.gui {
  if ($dialog($mIRCd.guiName) == $null) { dialog -m $mIRCd.guiName $mIRCd.guiName }
}
alias -l mIRCd.guiName { return mIRCd }
alias -l mIRCd.guiTimer { return mIRCd.guiUptime }
alias -l mIRCd.updateUptime { did -o $mIRCd.guiName 8 1 Uptime: $duration($calc($ctime - $hget($mIRCd.temp,startTime)),3) }

; EOF
