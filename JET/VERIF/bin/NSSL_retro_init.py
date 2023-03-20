#!/usr/bin/env python
#======================================================================================
# This script will check to see if NSSL files exit for a given date, and grab them from
# HPSS if they do no exist
#
# By: Jeff Hamilton
# Last Update: 14 JUNE 2017
#
# To execute: ./NSSL_retro_init.py
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

    obs_dir     = os.getenv("RETRODIR")
    hpss_dir  = os.getenv("HPSSDIR")

    #-----------------------------End of Definitions--------------------------------

    # Construct valid dir under run dir
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,valid_time)
    print valid_dir
    
    if (not os.path.isfile('%s/%s/nssl_mosaic.nc' % (obs_dir,valid_dir))):
        if (not os.path.isdir('%s/%s' % (obs_dir,valid_dir))):
            os.system('mkdir -p %s/%s' % (obs_dir,valid_dir))
        os.chdir('%s/%s' % (obs_dir,valid_dir))

        zipped_file = '%s%s%s%s.tgz' % (Year,Month,Day,valid_time)
         
        try:
            cmd = 'hsi get %s%s' % (hpss_dir,zipped_file)
            os.system(cmd)
        except:
            print 'NSSL files are not avaiable on HPSS for %s' % valid_dir
            return

        if (not os.path.isfile('%s/%s/%s' % (obs_dir,valid_dir,zipped_file))):
            print 'Problem downloading NSSL files from HPSS'
        else:
            try:
               cmd = 'tar -xvf %s' % zipped_file
               os.system(cmd)
            except:
               print 'Problem untarring the zipped file for %s' % valid_dir
           
        if (os.path.isfile('%s/%s/nssl_mosaic.nc' % (obs_dir,valid_dir))):
            print 'NSSL data downloaded successfully'
            cmd = 'rm -f %s/%s/%s' % (obs_dir,valid_dir,zipped_file)
        else:
            print 'ERROR: NSSL data not downloaded for %s' % valid_dir

    else:
        print 'NSSL files already exist for %s' % valid_dir

          
            
    os.chdir('..')

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
