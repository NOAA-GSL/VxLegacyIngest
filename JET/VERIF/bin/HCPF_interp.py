#!/usr/bin/env python
#======================================================================================
# This script will retrieve the HCPF data necessary for probabilistic verification
#
# By: Patrick Hofmann
# Last Update: 26 SEP 2013
#
# To execute: ./HCPF_interp.py
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
    
    # Looping variables
    forecast_leads = (os.getenv("FCSTLEADS")).split()
    
    # Static variables
    grib2_var = ':TSTM:'

    #-----------------------------End of Definitions--------------------------------

    # Construct valid dir under run dir
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,valid_time)
    print valid_dir
    
    if (not os.path.isdir('%s/%s' % (rt_dir,valid_dir))):
        os.system('mkdir -p %s/%s/03kmLC' % (rt_dir,valid_dir))
        
    os.chdir('%s/%s/03kmLC' % (rt_dir,valid_dir))
        
    t = datetime(int(Year),int(Month),int(Day),int(valid_time))

    for forecast_lead in forecast_leads:
        print forecast_lead
        # Use built-in Date/Time modules
        delta_t = timedelta(hours=-int(forecast_lead))
        ff_t = t #+ delta_t

        # Get model data
        forecast_dir = '%s/%s%02d%02d%02d/postprd' % (model_dir,ff_t.year,ff_t.month,ff_t.day,ff_t.hour)
        print forecast_dir
        forecast_file = 'wrftwo_ens_%02d' % int(forecast_lead)
        print forecast_file
        new_file = 'hcpf_%s%02d%02d%02dz+%02d' % (ff_t.year,ff_t.month,ff_t.day,ff_t.hour,int(forecast_lead))

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

            # Rename variable to prob
            os.system('ncrename -v TSTM_localleveltype2000,prob %s.nc' % new_file)
        else:
            print 'HCPF forecast missing'
            
    os.chdir('..')

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
