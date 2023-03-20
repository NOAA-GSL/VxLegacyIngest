#!/usr/bin/env python
#======================================================================================
# This script will retrieve and ungrib requested HRRR fields for verification.
#
# By: Patrick Hofmann
# Last Update: 22 APR 2013
#
# To execute: ./HRRR_init_verif.py
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
from datetime import timedelta
from datetime import date

def main():
    # Get environment variables
    Year       = os.getenv("YEAR")
    Month      = os.getenv("MONTH")
    Day        = os.getenv("DAY")
    valid_time = os.getenv("HOUR")

    rt_dir     = os.getenv("REALTIMEDIR")
    model_dir  = os.getenv("MODELDIR")
    model      = os.getenv("MODEL")

    grib2_var  = os.getenv("GRIB2VAR")

    # Looping variables
    forecast_leads = (os.getenv("FCSTLEADS")).split()

    #-----------------------------End of Definitions--------------------------------

    # Construct valid dir under run dir
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,valid_time)
    print valid_dir
    
    if (not os.path.isdir('%s/%s' % (rt_dir,valid_dir))):
        os.system('mkdir -p %s/%s' % (rt_dir,valid_dir))
        
    os.chdir('%s/%s' % (rt_dir,valid_dir))
        
    for forecast_lead in forecast_leads:
        print forecast_lead
        # Use built-in Date/Time modules
        t = datetime(int(Year),int(Month),int(Day),int(valid_time))
        delta_t = timedelta(hours=-int(forecast_lead))
        ff_t = t + delta_t

        # Have to get fancy with dates, since RUC wants day # of year
        ruc_ff = ff_t.strftime('%y%j%H')

        # Get model data
        forecast_file = '%s0000%s' % (ruc_ff,forecast_lead)
        print forecast_file
        new_file = '%s_%4d%02d%02d%02dz+%s' % (model,ff_t.year,ff_t.month,ff_t.day,ff_t.hour,forecast_lead)

        if (os.path.isfile('%s/%s.grib2' % (model_dir,forecast_file)) or \
            os.path.isfile('%s/%s' % (model_dir,forecast_file))):
            if (os.path.isfile('%s/%s.grib2' % (model_dir,forecast_file))):
                cmd = 'cp %s/%s.grib2 %s.grib2' % (model_dir,forecast_file,new_file)
            if (os.path.isfile('%s/%s' % (model_dir,forecast_file))):
                cmd = 'cp %s/%s %s.grib2' % (model_dir,forecast_file,new_file)
            print cmd
            os.system(cmd)
            
            # Ungrib HRRR file into NetCDF, remove grib2 file
            cmd = 'wgrib2 %s.grib2 | egrep "(%s)" | wgrib2 -i %s.grib2 -netcdf %s.nc' %  \
                  (new_file,grib2_var,new_file,new_file)
            print cmd
            os.system(cmd)
            os.remove('%s.grib2' % new_file)
        else:
            print 'HRRR forecast missing'
            
    os.chdir('..')

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
