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

# 2021:

I have decided to try and attempt this again from scratch.

Scripts are separated this time, and I am currently focusing on connection handling first before jumping ahead like I usually have a bad habit of doing.

27/06/2021: Connection handling is coming along nicely, as well as "Ping Timeout" and Socket errors.

-Jigsy
