# mIRCd
An IRCd written in mIRC scripting language (mSL) and more or less based on ircu based IRCds.

Not meant to be used as a proper IRCd since there's far better alternatives for that. (Like *actual* IRCds.)

Mainly doing this for my own personal amusement.

That said, this repo is currently a placeholder as the script is <a href="https://i.imgur.com/NkiGm8f.png">a work in progress</a>.

# Progress

A good majority of commands have been written (but not finished - E.g. unfinished error response parsing), while others have been started but not finished (E.g. OPMODE), and others don't exist yet (E.g. DIE)

However, I believe last Thursday that the script in question might have had a negative effect on my hard drive.

I'm sure I heard a dreaded click of death - though it could have been me scrolling with my mouse - and the Read Error Rate is being incredibly idiosyncratic - 10,008 > 8 > 8,000 > 0 > 9 > 9,000 > etc. - at the moment.

The S.M.A.R.T. health status is good, though.

As a result, I'm currently debating on if I should:

1. Risk the code as is
2. Split the commands into separate scripts such as mIRCd_MODE.mrc, mIRCd_PRIVMSG.mrc, etc. and test that
3. Or just abandon the project and just publish the unfinished code (which is currently under 90 KB)
