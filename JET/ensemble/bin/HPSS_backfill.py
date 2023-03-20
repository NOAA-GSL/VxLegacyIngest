#!/usr/bin/env python
#======================================================================================
# This script will retrieve grids from the HPSS.
#
# By: Jeff Hamilton
# Last Update: 14 NOV 2018
#
# To execute: ./HPSS_backfill.py
#
#---------------------------------------start-------------------------------------------
import sys
import os
import resource
from datetime import datetime
from datetime import date
from datetime import timedelta

def main():
    # Get environment variables
    Year       = os.getenv("YEAR")
    Month      = os.getenv("MONTH")
    Day        = os.getenv("DAY")
    valid_time = os.getenv("HOUR")

    rt_dir     = os.getenv("REALTIMEDIR")
    bf_dir     = os.getenv("BACKFILLDIR")
    model_dir  = os.getenv("MODELDIR")
    hpss_dir  = os.getenv("HPSSDIR")

    #-----------------------------End of Definitions--------------------------------

    # Construct valid dir under run dir
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,valid_time)
    print valid_dir
    
    if (not os.path.isdir('%s/%s' % (bf_dir,valid_dir))):
        os.system('mkdir -p %s/%s' % (bf_dir,valid_dir))
        
        
    # Use built-in Date/Time modules
    t = datetime(int(Year),int(Month),int(Day),int(valid_time))

    # Get data from HPSS

    os.chdir('%s/%s' % (bf_dir,valid_dir))

    cmd = 'hsi get %s/%s%02d%02d%02d.tgz' % (hpss_dir,t.year,t.month,t.day,t.hour)
    print cmd
    os.system(cmd)

    cmd = 'tar -xvf %s%02d%02d%02d.tgz' % (t.year,t.month,t.day,t.hour)
    print cmd
    os.system(cmd)

    cmd = 'rm -f %s%02d%02d%02d.tgz' % (t.year,t.month,t.day,t.hour)
    print cmd
    os.system(cmd)

    cmd = 'cp %s/%s/%s/%s/* .' % (bf_dir,valid_dir,rt_dir,valid_dir)
    print cmd
    os.system(cmd)

    cmd = 'rm -rf %s/%s/home' % (bf_dir,valid_dir)
    print cmd
    #os.system(cmd)

    cmd = 'rm -rf %s/%s/tmp' % (bf_dir,valid_dir)
    print cmd
    #os.system(cmd)

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
