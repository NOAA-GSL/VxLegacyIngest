#!/bin/tcsh -f
#run this from crontab
#clean up scratch file
cd ~/utilities
set recipient = "moninger"
#to turn on mail, flip the two lines below and comment out the upper one.
#/usr/lib/sendmail $recipient << ENDFLAG
cat > /dev/null << ENDFLAG
To: $recipient
From: utilities/purgeScratch30.s
Subject: deleted 30+ day old files
run via crontab on `date -u +"%y%j%H%M"` (`date`)
these files are 30 or more days old, and are being deleted:
`find scratch -follow -type f -mtime +30 -print -exec rm {} \;`
ENDFLAG
