; mIRCd_gui.mrc
;
; Note: I honestly don't use dialogs in mIRC. I prefer the command line approach to life. But this is for your benefit, not mine.

dialog mIRCd {
  title "mIRCd - [/mIRCd.gui]"
  size -1 -1 89 109
  option dbu

  box "", 1, 3 0 84 68
  button "&LOAD", 2, 6 4 77 9
  button "&START", 3, 6 16 77 8
  box "", 4, 3 25 84 4
  button "&DIE", 5, 6 32 77 8
  button "RE&HASH", 6, 6 44 77 8
  button "&RESTART", 7, 6 54 77 8
  box "", 8, 3 64 84 17
  button "&MKPASSWD", 9, 6 69 77 8
  edit "", 10, 3 83 84 8, disable
  button "&Close", 11, 49 98 37 8, default ok
}
on *:dialog:mIRCd:*:*:{
  if ($devent == close) {
    if ($timer($mIRCd.guiTimer) != $null) { $+(.timer,$mIRCd.guiTimer) off }
  }
  if ($devent == init) {
    if ($sock(mIRCd.*,0) > 0) { did -o $dname 3 1 &START (already running) }
    if ($mIRCd(startTime).temp != $null) {
      $+(.timer,$mIRCd.guiTimer) -o 0 1 mIRCd.updateUptime
    }
    else { did -o $dname 10 1 Uptime: N/A }
  }
  if ($devent == sclick) {
    if ($did == 2) { mIRCd.load }
    if ($did == 3) {
      mIRCd.start
      if ($sock(mIRCd.*,0) > 0) { did -o $dname 3 1 &START (running) }
      if ($mIRCd(startTime).temp != $null) {
        if ($timer($mIRCd.guiTimer) == $null) { $+(.timer,$mIRCd.guiTimer) -o 0 1 mIRCd.updateUptime }
      }
    }
    if ($did == 5) {
      mIRCd.die
      if ($timer($mIRCd.guiTimer) != $null) { $+(.timer,$mIRCd.guiTimer) off }
      if ($sock(mIRCd.*,0) > 0) {
        did -o $dname 10 1 N/A
        did -o $dname 3 1 &START
      }
    }
    if ($did == 6) { mIRCd.rehash }
    if ($did == 7) { mIRCd.restart }
    if ($did == 9) { write -c $qt($scriptdirmkpasswd.txt) $mIRCd.encryptPass($input(Enter a password:,p,Enter a password)) }
  }
}
alias mIRCd.gui {
  if ($dialog($mIRCd.guiName) == $null) { dialog -m $mIRCd.guiName $mIRCd.guiName }
}
alias -l mIRCd.guiName { return mIRCd }
alias -l mIRCd.guiTimer { return mIRCd.guiUptime }
alias -l mIRCd.updateUptime { did -o $mIRCd.guiName 10 1 Uptime: $duration($calc($ctime - $mIRCd(startTime).temp),3) }

; EOF
