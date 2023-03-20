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
import subprocess
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

    model      = os.getenv("MODEL")
    grib2_var  = os.getenv("GRIB2VAR")

    # Looping variables
    forecast_leads = (os.getenv("FCSTLEADS")).split()

    members = (os.getenv("ENSEMBLE_MEMBERS")).split()

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
        
        for member in members:

          # Get model data
          if (model == 'hrrr'):
              forecast_dir = '%s/%s%02d%02d%02d/postprd' % (model_dir,ff_t.year,ff_t.month,ff_t.day,ff_t.hour)
              forecast_file = 'wrftwo_hrconus_%s' % forecast_lead
          elif (model == 'rap'):
              forecast_dir = '%s/%s%02d%02d%02d/postprd' % (model_dir,ff_t.year,ff_t.month,ff_t.day,ff_t.hour)
              forecast_file = 'wrftwo_130_%s' % forecast_lead
          elif (model == 'ruc'):
              forecast_dir = model_dir
              forecast_file = '%s0000%s' % (ff_t.strftime('%y%j%H'),forecast_lead)
          elif (model == 'hrrre'):
              forecast_dir = '%s/%s%02d%02d%02d/postprd_mem%04d' % (model_dir,ff_t.year,ff_t.month,ff_t.day,ff_t.hour,int(member))
              forecast_file = 'wrftwo_conus_mem%04d_%s' % (int(member),forecast_lead)
          elif (model == 'rrfse'):
              forecast_dir = '%s/RRFS_conus_3km.%s%02d%02d/%02d/mem%04d' % (model_dir,ff_t.year,ff_t.month,ff_t.day,ff_t.hour,int(member))
              forecast_file = 'RRFS_CONUS.t%02dz.bgrd3df%03d.tm00' % (ff_t.hour,int(forecast_lead))
        
        
          print forecast_dir
          print forecast_file
          new_file = '%s_mem%04d_%s%02d%02d%02dz+%s' % (model,int(member),ff_t.year,ff_t.month,ff_t.day,ff_t.hour,forecast_lead)

          if (os.path.isfile('%s/%s.grib2' % (forecast_dir,forecast_file))):
              cmd = 'cp %s/%s.grib2 %s.grib2' % (forecast_dir,forecast_file,new_file)
              print cmd
              os.system(cmd)
         
              # Ungrib model file into NetCDF, remove grib2 file
              cmd = 'wgrib2 %s.grib2 | egrep "(%s)" | wgrib2 -i %s.grib2 -netcdf %s.nc' %  \
                    (new_file,grib2_var,new_file,new_file)
              print cmd
              os.system(cmd)
              os.remove('%s.grib2' % new_file)
          else:
              print '%s forecast missing' % model
            

    os.chdir('..')

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
