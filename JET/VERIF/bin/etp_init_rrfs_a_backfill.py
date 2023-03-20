#!/usr/bin/env python
#======================================================================================
# This script will retrieve and ungrib requested HRRR/RAP/RUC fields for verification.
#
# By: Patrick Hofmann
# Last Update: 14 FEB 2014
#
# To execute: ./cref_init.py
#
# Example HRRR file: wrftwo_hrconus_FF.grib2
# Recent (1-2 days) dir: /misc/whome/rtrr/hrrr/YYYYMMDDHH/postprd/
# Archive dir: /arch2/fdr/YYYY/MM/DD/data/fsl/hrrr/conus/wrftwo/YYYYMMDDHH00.tar.gz
# * files in clumps of 3 hours starting at 00
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
    model_dir  = os.getenv("MODELDIR")
    mss_dir  = os.getenv("HPSSDIR")

    model      = os.getenv("MODEL")
    grib2_var  = os.getenv("GRIB2VAR")

    # Looping variables
    forecast_leads = (os.getenv("FCSTLEADS")).split()

    #-----------------------------End of Definitions--------------------------------

        
    t = datetime(int(Year),int(Month),int(Day),int(valid_time))
        
    # Get data from HPSS
    forecast_dir = '%s/rrfs_a.%s%02d%02d/%02d' % (model_dir,t.year,t.month,t.day,t.hour)
    hpss_dir = '%s/rh%s/%s%02d/%s%02d%02d/%02d/prod' % (mss_dir,t.year,t.year,t.month,t.year,t.month,t.day,t.hour)

    if (not os.path.isdir('%s' % (forecast_dir))):
       cmd = 'mkdir -p %s' % (forecast_dir)
       os.system(cmd)
       
    os.chdir(forecast_dir)
 
    tar_file = 'rrfs.t%02dz.prslev.conus_3km.grib2.tar' % (t.hour)

    cmd = 'hsi get %s/%s' % (hpss_dir,tar_file)
    print cmd
    os.system(cmd)

    if (os.path.isfile('%s' % (tar_file))):
       cmd = 'tar -xvf %s' % (tar_file)
       print cmd
       os.system(cmd)
    else:
       print 'tar file %s not found, exiting...' % (tar_file)
       exit(2)

    for forecast_lead in forecast_leads:
        delta_t = timedelta(hours=int(forecast_lead))
        ff_t = t + delta_t

        # Construct valid dir under run dir
        valid_dir = '%04d%02d%02d-%02dz' % (ff_t.year,ff_t.month,ff_t.day,ff_t.hour)
    
        # Get model data
        
        forecast_file = 'rrfs.t%02dz.prslev.f%03d.conus_3km.grib2' % (t.hour,int(forecast_lead))

        print forecast_dir
        print forecast_file
        new_file = '%s_%s%02d%02d%02dz+%s' % (model,t.year,t.month,t.day,t.hour,forecast_lead)


        if (os.path.isfile('%s/%s' % (forecast_dir,forecast_file))):
            print 'Processing %s hour forecast for %s' % (forecast_lead,model) 
            if (not os.path.isdir('%s/%s' % (rt_dir,valid_dir))):
               os.system('mkdir -p %s/%s' % (rt_dir,valid_dir))

            os.chdir('%s/%s' % (rt_dir,valid_dir))
            print valid_dir

            cmd = 'cp %s/%s %s.grib2' % (forecast_dir,forecast_file,new_file)
            print cmd
            os.system(cmd)
            
            # Ungrib model file into NetCDF, remove grib2 file
            cmd = 'wgrib2 %s.grib2 | egrep "(%s)" | wgrib2 -i %s.grib2 -netcdf %s.nc' %  \
                  (new_file,grib2_var,new_file,new_file)
            print cmd
            os.system(cmd)
            os.remove('%s.grib2' % new_file)
        else:
            print '%s %s hour forecast missing' % (model,forecast_lead)
            
#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
