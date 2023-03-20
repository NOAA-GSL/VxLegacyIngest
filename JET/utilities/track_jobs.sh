#!/bin/ksh

export job_date=$(date +%Y%m%d%H)

showq -n -c | grep amb-verif > $HOME/utilities/tmp/job_tracker_$job_date 2>&1



