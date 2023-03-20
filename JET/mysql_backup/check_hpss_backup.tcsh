#!/bin/tcsh

module load hpss
set rootdir = `dirname $0`
cd $rootdir
echo $PWD
./check_hpss_backup.py
