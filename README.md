# mIRCd
An IRCd written in mIRC scripting language (mSL) and more or less based on ircu based IRCds.

Not meant to be used as a proper IRCd since there's far better alternatives for that. (Like *actual* IRCds.)

Mainly doing this for my own personal amusement.

# Progress (old - 0.03)

Seeing as I haven't touched this in about two months, I'm just going to upload what I've done.

A lot of commands haven't been finished (response wise, and the like), and there's no error checking. (Esp. with the config.)

You can however join channels, part channels, disconnect, set modes (to an extent), talk, etc.

If you want to try the IRCd for yourself, tweak the config, then do /mIRCd.load followed by /mIRCd.start.

Then just connect to localhost on the port(s) used. E.g. /server localhost 6667

# 2021 (Revision 2):

I have decided to try and attempt this again from scratch.

Scripts are separated this time, and I am currently focusing on connection handling first before jumping ahead like I usually have a bad habit of doing.

27/06/2021: Connection handling is coming along nicely, as well as "Ping Timeout" and Socket errors.

06/07/2021: A good majority of stuff has been completed, channel handling and so forth. A bunch of commands need finishing, and I might recode some of the commands to make them suck less or to replace them with non-nested code. (Looking at you, MODE parsing!)

08/07/2021: MODE parsing completely rewritten - it still follows the same rules as v0 (unused), but I've tried to condense it into one group. Also wrote a n!u@h maker, so +b supported. (Which means SILENCE, SHUN and a few other things should now be possible.)

-Jigsy
