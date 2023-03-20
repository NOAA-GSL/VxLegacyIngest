#!/usr/bin/env python
#=====================================================================================
# This script will archive Composite Reflectivity verification grids
#
# By: Patrick Hofmann
# Last Update: 17 MAR 2012
#
# To execute: ./cref_arch.py
#
#-------------------------------------start-------------------------------------------
import sys
import os
import tarfile
import glob
from datetime import datetime
from datetime import timedelta

def main():
    # Get environment variables
    Year         = os.getenv("YEAR")
    Month        = os.getenv("MONTH")
    Day          = os.getenv("DAY")
    Hour         = os.getenv("HOUR")

    web_dir      = os.getenv("WEBDIR")
    mss_dir      = os.getenv("MSSDIR")
    grids_dir    = os.getenv("GRIDDIR")
    verif_dir    = os.getenv("VERIFDIR")
    log_dir      = os.getenv("LOGDIR")
    master_log_dir       = os.getenv("WFLOGDIR")

    # Use built-in Date/Time modules
    t = datetime(int(Year),int(Month),int(Day),int(Hour))
    
    for hr in range(0,24):
        job = False
        count = 1

        delta_t = timedelta(hours=hr)
        new_t   = t + delta_t

        while (job == False and count < 3):
            # Construct valid dir and archive dir
            valid_dir = '%4d%02d%02d-%02dz' % (new_t.year,new_t.month,new_t.day,new_t.hour)
            valid_date = '%4d%02d%02d%02d' % (new_t.year,new_t.month,new_t.day,new_t.hour)

            web_valid_dir = '%4d%02d%02d%02d' % (new_t.year,new_t.month,new_t.day,new_t.hour)
            
            print 'Moving: ', valid_dir, ' To: ', mss_dir

            if (os.path.isdir('%s/%s' % (grids_dir,valid_dir))):
                dir = '%s/%s' % (grids_dir,valid_dir)
                print dir
                os.chdir(dir)
            else:
                break
        
            # Tar and move raw model grids and interpolated grids
            tarname = '%s/%4d%02d%02d%02d.tgz' % (mss_dir,new_t.year,new_t.month,new_t.day,new_t.hour)

            files = ''
            if (verif_dir == 'StageIV'):
                for file in glob.glob('%s/%s/*' % (grids_dir,valid_dir)):
                    print 'adding %s' % file
                    files = files + ' ' + file
            else:
                for file in glob.glob('%s/%s/*.nc' % (grids_dir,valid_dir)):
                    print 'adding %s' % file
                    files = files + ' ' + file
                for file in glob.glob('%s/%s/*.nc' % (verif_dir,valid_dir)):
                    print 'adding %s' % file
                    files = files + ' ' + file
                for file in glob.glob('%s/%s/*kmLC/*.nc' % (verif_dir,valid_dir)):
                    print 'adding %s' % file
                    files = files + ' ' + file
                for file in glob.glob('%s/%s/*kmLC/*.txt' % (verif_dir,valid_dir)):
                    print 'adding %s' % file
                    files = files + ' ' + file
                for file in glob.glob('%s/%s/*kmLC/*.png' % (verif_dir,valid_dir)):
                    print 'adding %s' % file
                    files = files + ' ' + file

            # Create tarball on HSMS
            cmd = 'htar -cvf %s %s' % (tarname,files)
            print cmd
            os.system(cmd)
            
            # Check for existance of tarball
            cmd = 'hsi ls %s' % tarname
            print cmd
            err = os.system(cmd)
            if (err == 0):
                job = True
                
            count = count + 1

        # Remove directories
        os.system('cd ..')
        cmd = 'rm -rf %s/%s' % (grids_dir,valid_dir)
        print cmd
        os.system(cmd)
        
        os.system('cd ..')
        cmd = 'rm -rf %s/%s' % (web_dir,web_valid_dir)
        print cmd
        os.system(cmd)
        
        cmd = 'rm -rf %s/%s' % (verif_dir,valid_dir)
        print cmd
        os.system(cmd)
        
        cmd = 'rm -f %s/*%s*' % (log_dir,valid_date)
        print cmd
        os.system(cmd)

        cmd = 'rm -f %s/*%s*' % (master_log_dir,valid_date)
        print cmd
        os.system(cmd)
                
        
        
        
#-----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
