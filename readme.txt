mIRCd v0.09hf3 (Revision 2) - by Jigsy (https://github.com/Jigsy1/mIRCd)
---------------------------------------------------------------------------

Files included in this release:

* conf\help\*.help	 - These are help files which are viewed by doing: /raw HELP commandName
* conf\nicks.403	 - Nicks that are prohibited from being used. E.g. ChanServ, NickServ, X, etc.
* conf\mIRCd.klines	 - A list of K-lines. (These are not unset.)
* con\mIRCd.raws	 - Raw numeric replies. (I strongly recommended leaving this file alone.)
* conf\INFO.txt		 - Called when doing: /INFO
* misc\debugUser.mrc	 - A simple socket clone user used for debugging.
* notes\*.txt		 - Contains some general information. (E.g. Reserved modes, etc.)
* mIRCd.motd		 - This is your MOTD file. Feel free to change it. (Note: mIRC doesn't like excessive spaces.)
* mIRCd.mrc/mIRCd_*.mrc	 - These are the core of the IRCd. (You will need all of them loaded.)
* *.bat files		 - Quick and dirty way of doing things. (Such as terminating the IRCd, etc.)

Note: The *.bat files will not work without the following: http://xise.nl/mirc/sigmirc.zip


Setting up mIRCd:

1. Load mIRCd.mrc into mIRC either by /load -rs "P:\ath\to\mIRCd.mrc" or via the editor.
   This will throw up a warning. Say "Yes," and then let it load all the remaining scripts for you.
   (If it doesn't, load all of them - mIRCd_*.mrc - one-by-one.)

2. Edit mIRCd.ini to change certain settings like the SERVER_NAME, SALT, etc.

3. To load everything into memory, type: /mIRCd.load
   You can also do this via the Menubar, /mIRCd.gui or by LOAD.bat.

4. Generate a password for your Oper account, by doing: /mIRCd.mkpasswd password
   You can also do /raw MKPASSWD password when connected to the server, or via MKPASSWD.bat which will dump a sha512
   hash into a file called mkpasswd.txt. (Copy that into mIRCd.ini.)

*!*!* WARNING(!): It is strongly recommended also setting separate passwords for /DIE and /RESTART *!*!*

5. Rehash the Opers section into memory by doing: /mIRCd.rehash Opers
   You can also do this via the Menubar, /mIRCd.gui or REHASH.bat.

6. Start the server by doing: /mIRCd.start
   You can also do this via the Menubar, /mIRCd.gui or START.bat.

7. Connect to the server via: /server localhost 6667
   Or, if you're running this on another LAN machine: /server your.lan.ip 6667
   If you wish to get other people to connect - depending on firewall/router rules - it'll be: /server your.public.ip 6667

To terminate the IRCd, do: /mIRCd.die
You can also do this via the Menubar, /mIRCd.gui or DIE.bat.

If you wish to unload the scripts, do /unload -rs "P:\ath\to\mIRCd.mrc" or via the editor.
This should unload all the remaining scripts for you. (If it doesn't, unload all of them - mIRCd_*.mrc - one-by-one.)

Note: Unloading the script should also terminate the IRCd and unload memory for you.


; EOF