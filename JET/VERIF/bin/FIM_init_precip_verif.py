#!/usr/bin/env python
#======================================================================================
# This script will first retrieve and ungrib all the FIM data for Precip verification
#
# By: Eric James
# Last Update: 11 JUN 2015
#
# To execute: ./FIM_init_cref_verif.py
#
# Example FIM file: YYDDDHH0000FF.grib2
# Recent (1-2 days) dir: /home/rtfim/FIM/FIMrun/
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
    init_time  = os.getenv("HOUR")
    
    rt_dir     = os.getenv("REALTIMEDIR")
    model_dir  = os.getenv("MODELDIR")
    exec_dir   = os.getenv("EXECDIR")
    
    # Looping variables
    leads          = os.getenv("FCSTLEADS")
    forecast_leads = leads.split()
    
    # Static variables
    pcp_var = ':APCP:'

    #-----------------------------End of Definitions--------------------------------

    # First, set stacksize to 512MB
    resource.setrlimit(resource.RLIMIT_STACK,(800000000,800000000))
    
    # Construct valid dir under run dir
    init_dir = '%s%s%s-%sz' % (Year,Month,Day,init_time)
    print init_dir

    if (not os.path.isdir('%s/%s' % (rt_dir,init_dir))):
        os.system('mkdir -p %s/%s' % (rt_dir,init_dir))
    
    os.chdir('%s/%s' % (rt_dir,init_dir))
    
    # Use built-in Date/Time modules
    t = datetime(int(Year),int(Month),int(Day),int(init_time))

    date_str = '%4d%02d%02d%02d' % (t.year,t.month,t.day,t.hour)
    init_file = 'fim_%sz' % (date_str)
    
    # Have to get fancy with dates, since FIM wants day # of year
    fim_ff = t.strftime('%y%j%H')
        
    for forecast_lead in forecast_leads:
        print forecast_lead

        # Get model data
        forecast_file = '%s000%s' % (fim_ff,forecast_lead)
        print forecast_file
        new_file = 'fim_%sz+%s' % (date_str,forecast_lead)

        if (os.path.isfile('%s/%s/post_C/130/NAT/grib2/%s' % (model_dir,date_str,forecast_file))):
            cmd = 'cp %s/%s/post_C/130/NAT/grib2/%s %s.grib2' % (model_dir,date_str,forecast_file,new_file)
            print cmd
            os.system(cmd)
            
            # Ungrib FIM file into NetCDF, remove grib2 file
            start = 0
            end = int(forecast_lead)
            if (forecast_lead == '024'):
                cmd = 'wgrib2 %s.grib2 | egrep "(%ssurface:0-1 day acc fcst:)" | wgrib2 -i %s.grib2 -netcdf %s.nc' % \
                      (new_file,pcp_var,new_file,new_file)
            else:
                cmd = 'wgrib2 %s.grib2 | egrep "(%ssurface:%d-%d hour acc fcst:)" | wgrib2 -i %s.grib2 -netcdf %s.nc' %  \
                      (new_file,pcp_var,start,end,new_file,new_file)
            print cmd
            os.system(cmd)
            os.remove('%s.grib2' % new_file)

        else:
            print 'FIM forecast missing'

    # Put files in correct format
    cmd = 'cp %s+006.nc fim_%sz_06hr_total.nc' % (init_file,date_str)
    print cmd
    os.system(cmd)

    cmd = 'cp %s+012.nc fim_%sz_12hr_total.nc' % (init_file,date_str)
    print cmd
    os.system(cmd)

    cmd = 'cp %s+024.nc fim_%sz_24hr_total.nc' % (init_file,date_str)
    print cmd
    os.system(cmd)

    os.chdir('..')

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
