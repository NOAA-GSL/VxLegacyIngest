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
              forecast_file = 'wrftwo_mem%04d_%s' % (int(member),forecast_lead)
        
          print forecast_dir
          print forecast_file
          new_file = '%s_mem%04d_%s%02d%02d%02dz+%s' % (model,int(member),ff_t.year,ff_t.month,ff_t.day,ff_t.hour,forecast_lead)

          if (os.path.isfile('%s/%s.grib2' % (forecast_dir,forecast_file))):
              cmd = 'cp %s/%s.grib2 %s.grib2' % (forecast_dir,forecast_file,new_file)
              print cmd
              os.system(cmd)
         
              #Check to see which region we are in for furture database loading
              cmd1 = 'wgrib2'
              cmd2 = '-grid'
              cmd3 = '%s.grib2' % new_file
              print cmd
              proc = subprocess.Popen([cmd1,cmd2,cmd3], stdout=subprocess.PIPE)
              while True:
                tmp = proc.stdout.readline()
                if tmp != '':
                  lines = tmp.split()
                  if len(lines) > 1:
                    line1 = lines[0]
                    line2 = lines[1]
                    if line1 == "Lat1" and line2 == "24.039825":
                      os.environ["ENSEMBLE_REGION"] = "South"
                      os.environ["GRID_REGION"] = "S"
                    elif line1 == "Lat1" and line2 == "25.522041":
                      os.environ["ENSEMBLE_REGION"] = "Southeast"
                      os.environ["GRID_REGION"] = "SE"
                    elif line1 == "Lat1" and line2 == "35.248077":
                      os.environ["ENSEMBLE_REGION"] = "Northeast"
                      os.environ["GRID_REGION"] = "NE"
                    elif line1 == "Lat1" and line2 == "29.119377":
                      os.environ["ENSEMBLE_REGION"] = "Central"
                      os.environ["GRID_REGION"] = "C"
                    elif line1 == "Lat1" and line2 == "36.447021":
                      os.environ["ENSEMBLE_REGION"] = "North"
                      os.environ["GRID_REGION"] = "N"
                else:
                  break
            
              # Ungrib model file into NetCDF, remove grib2 file
              cmd = 'wgrib2 %s.grib2 | egrep "(%s)" | wgrib2 -i %s.grib2 -netcdf %s.nc' %  \
                    (new_file,grib2_var,new_file,new_file)
              print cmd
              os.system(cmd)
              os.remove('%s.grib2' % new_file)
          else:
              print '%s forecast missing' % model
            
    region      = os.getenv("ENSEMBLE_REGION")
    print region

    os.chdir('..')

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
