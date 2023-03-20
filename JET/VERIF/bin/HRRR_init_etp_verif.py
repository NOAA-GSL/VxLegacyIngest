#!/usr/bin/env python
#======================================================================================
# This script will first retrieve and ungrib all the HRRR data necessary for ECHOTOP
# verification.
#
# By: Patrick Hofmann
# Last Update: 08 JUN 2012
#
# To execute: ./HRRR_init_etp_verif.py
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

def main():
    # Get environment variables
    Year       = os.getenv("YEAR")
    Month      = os.getenv("MONTH")
    Day        = os.getenv("DAY")
    valid_time = os.getenv("HOUR")

    rt_dir     = os.getenv("REALTIMEDIR")
    model_dir  = os.getenv("MODELDIR")

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

        # Get model data
        forecast_dir = '%s/%s%02d%02d%02d/postprd' % (model_dir,ff_t.year,ff_t.month,ff_t.day,ff_t.hour)
        print forecast_dir
        forecast_file = 'wrftwo_hrconus_%s' % forecast_lead
        print forecast_file
        new_file = 'hrrr_%s%02d%02d%02dz+%s' % (ff_t.year,ff_t.month,ff_t.day,ff_t.hour,forecast_lead)

        if (os.path.isfile('%s/%s.grib2' % (forecast_dir,forecast_file))):
            cmd = 'cp %s/%s.grib2 %s.grib2' % (forecast_dir,forecast_file,new_file)
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
