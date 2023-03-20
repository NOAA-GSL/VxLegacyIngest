#!/bin/tcsh -f
#run this from crontab
#clean up scratch file
cd ~/utilities
#/usr/lib/sendmail moninger << ENDFLAG
cat << ENDFLAG > purgeRecord
To: moninger
From: utilities/purgeHybdata.s
Subject: deleted most 1+ day old files in /scratch/maps/moninger/hybdata
run via crontab on `date -u +"%y%j%H%M"` (`date`)
(this should not delete *bin files)
these files are 1 or more days old, and are being deleted:
`find scratch/hybdata -type f ! -name "*bin" -mtime +1 -print -exec rm {} \;`

these \*.bin files are 20 days old, and are being deleted
`find scratch/hybdata -type f -name "*bin" -mtime +20 -print -exec rm {} \;`
ENDFLAG
