# mIRCd
An IRCd written in mIRC scripting language (mSL) and more or less based on ircu based IRCds.

Not meant to be used as a proper IRCd since there's far better alternatives for that. (Like *actual* IRCds.)

Mainly did this for my own personal amusement.

Limitations:
---------------
* This could be used by nefarious actors to phish NickServ passwords, so end users should be wary of this
* No SSL/TLS support (socklisten doesn't support these)
* Not IRCv3 compliant (though I personally don't consider this to be a bad thing)
* Some commands are missing: WHO, WHOWAS and anything related to server linking (BURST, etc.)

Please consult readme.txt on how to get it running. -Jigsy
