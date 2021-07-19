@echo off
echo This will output the password into a file called mkpasswd.txt.
echo. 
set /P thisPassword="Enter a password: "
sigmirc mIRCd MKPASSWD %thisPassword%
