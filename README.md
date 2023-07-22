# mIRCd
An IRCd written in mIRC Scripting Language (mSL) and more or less based on ircu based IRCds.

This is not meant to be used as a proper IRCd since there's far better alternatives for that. (Like *actual* IRCds.)

I mainly did this for my own personal amusement/as a pet project.


## Requirements:
* At least mIRC v7.66


## Limitations:
* This could be used by nefarious actors to phish NickServ/Oper passwords, so end users should be wary of this
* No SSL/TLS support (/socklisten doesn't support these)
* Not IRCv3 compliant (though I personally don't consider this to be a bad thing as IRC conversation is supposed to be ephemeral)
* No flood protection such as Excess Flood
* Sockets have a max size they can send data (Interestingly, this limitation didn't exist in mIRC 6.35 ¬_¬)
* Some commands are missing: anything related to server linking (ACCOUNT, BURST, JUPE, etc.)

Please consult readme.txt on how to get it running. -Jigsy


##### Things I would at least like to try to do some day:
* Giving the entire script a line-by-line once over to check for bugs.
* Server linking. Though given the nature of this, it's going to require me to rescript the entire IRCd from scratch. (Rev.3)

###### Screenshots

<img src="https://user-images.githubusercontent.com/34282672/211921072-acef6be8-60a5-46fe-8ea6-5d5022f22ab4.png" width="25%" height="25%" title="Channel and /WHOIS reply" /> <img src="https://user-images.githubusercontent.com/34282672/211921076-3ab9a730-7ec2-4e8c-b366-b777628f650c.png" width="25%" height="25%" title="Setting a /GLINE" /> <img src="https://user-images.githubusercontent.com/34282672/211921080-cbb5c4bd-1575-48d1-940f-2c09b8de611e.png" width="25%" height="25%" title="G-lined on connection" />
<img src="https://user-images.githubusercontent.com/34282672/211921083-963f98ce-b964-4d6c-bfdd-3ed46de4efd4.png" width="25%" height="25%" title="G-lining a channel" /> <img src="https://user-images.githubusercontent.com/34282672/211921086-03977227-3244-44b1-8f1b-81d857d62082.png" width="25%" height="25%" title="/OPMODE and /MODE changes" /> <img src="https://user-images.githubusercontent.com/34282672/211921087-ccce2f9b-db0f-4b73-acdd-050a95942fb6.png" width="25%" height="25%" title="Status window" />
<img src="https://user-images.githubusercontent.com/34282672/214992267-840efb96-e188-423c-871c-07017e919d2c.png" width="25%" height="25%" title="/WHO" /> <img src="https://github.com/Jigsy1/mIRCd/assets/34282672/86b41cc3-a35b-4183-8e1a-ec5783af76dd" width="25%" height="25%" title="Own idea: /WHO returning connection time" /> <img src="https://github.com/Jigsy1/mIRCd/assets/34282672/2a2719f3-5e94-410c-85d5-c596fe41300f" width="25%" height="25%" title="Extended /LIST" />
