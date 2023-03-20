#!/usr/bin/env python
#======================================================================================
# This script will first retrieve and ungrib all the RUC data for CREF verification
#
# By: Patrick Hofmann
# Last Update: 08 OCT 2010
#
# To execute: ./RUC_init_cref_verif.py
#
# Example RUC file: YYDDDHH0000FF.grib2
# Recent (1-2 days) dir: /home/rtruc/ruc_backup/ruc_presm/
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
    
    # Looping variables
    leads          = os.getenv("FCSTLEADS")
    forecast_leads = leads.split()
    
    # Static variables
    grib2_var = ':REFC:'

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
        if ("mhu/wcoss" in model_dir):
            if (model == 'hrrr'):
                forecast_file = '%s%02d%02d%02d/postprd/hrrr.t%02dz.wrfprsf%s.grib2' % (ff_t.year,ff_t.month,ff_t.day,ff_t.hour,ff_t.hour,forecast_lead)
            else:
                forecast_file = '%s%02d%02d%02d/postprd/rap.t%02dz.awp130pgrbf%s.grib2' % (ff_t.year,ff_t.month,ff_t.day,ff_t.hour,ff_t.hour,forecast_lead)
        else:
            forecast_file = '%s0000%s' % (ruc_ff,forecast_lead)
        print forecast_file
        new_file = '%s_%4d%02d%02d%02dz+%s' % (model,ff_t.year,ff_t.month,ff_t.day,ff_t.hour,forecast_lead)

        print ('%s/%s' % (model_dir,forecast_file))
        if (os.path.isfile('%s/%s.grib2' % (model_dir,forecast_file)) or \
            os.path.isfile('%s/%s' % (model_dir,forecast_file))):
            if (os.path.isfile('%s/%s.grib2' % (model_dir,forecast_file))): 
                cmd = 'cp %s/%s.grib2 %s.grib2' % (model_dir,forecast_file,new_file)
            if (os.path.isfile('%s/%s' % (model_dir,forecast_file))):
                cmd = 'cp %s/%s %s.grib2' % (model_dir,forecast_file,new_file)
            print cmd
            os.system(cmd)
            
            # Ungrib RR file into NetCDF, remove grib2 file
            cmd = 'wgrib2 %s.grib2 | egrep "(%s)" | wgrib2 -i %s.grib2 -netcdf %s.nc' %  \
                  (new_file,grib2_var,new_file,new_file)
            print cmd
            os.system(cmd)
            os.remove('%s.grib2' % new_file)
        else:
            print 'RR forecast missing'
            
    os.chdir('..')

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
