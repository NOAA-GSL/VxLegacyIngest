#!/usr/bin/env python
#=====================================================================================
# This script will archive Composite Reflectivity verification grids
#
# By: Patrick Hofmann
# Last Update: 17 NOV 2010
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

    mss_dir      = os.getenv("MSSDIR")
    rt_dir       = os.getenv("REALTIMEDIR")

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
            
            print 'Moving: ', valid_dir, ' To: ', mss_dir
            
            dir = '%s/%s' % (rt_dir,valid_dir)
            print dir
            os.chdir(dir)
            #print os.getcwd()
        
            # Tar and move raw model grids and interpolated grids
            try:
                tf = tarfile.open('%s/%4d%02d%02d%02d_img.tgz' % (mss_dir,new_t.year,new_t.month,new_t.day,new_t.hour),'w:gz')
                for file in glob.glob('*.png'):
                    print 'adding %s' % file
                    tf.add(file)
                for file in glob.glob('*kmLC/*.png'):
                    print 'adding %s' % file
                    tf.add(file)
                tf.close()
            except TarError, err:
                print 'ERROR: could not open tarfile'
            
            try:
                test = tarfile.open('%s/%4d%02d%02d%02d_img.tgz' % (mss_dir,new_t.year,new_t.month,new_t.day,new_t.hour),'r:gz')
                test.close()
                
                # Remove NC grids
                #cmd = 'rm -rf *.png *kmLC/*.png'
                #print cmd
                #os.system(cmd)

                job = True
            
            except tarfile.ReadError, err:
                print 'File not tarred'
                
            count = count + 1

        

                
        
        
        
#-----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
