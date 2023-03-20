#!/bin/tcsh -f
# file ~/utilities/monitor.s
#run this from crontab
cd ~/utilities
rm monitor.temporaryFile
monitor.x > monitor.temporaryFile
if($status != 0) then
/usr/lib/sendmail moninger << ENDFLAG
To: moninger
From: utilities/monitor.s
Subject: `cat monitor.temporaryFile`
run via crontab on `date -u +"%y%j%H%M "` (`date`)
ENDFLAG
endif

