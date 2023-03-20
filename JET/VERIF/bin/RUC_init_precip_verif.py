#!/usr/bin/env python
#======================================================================================
# This script will first retrieve and ungrib all the RUC data for Precip verification
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
    init_time  = os.getenv("HOUR")
    
    rt_dir     = os.getenv("REALTIMEDIR")
    model_dir  = os.getenv("MODELDIR")
    exec_dir   = os.getenv("EXECDIR")
    
    # Looping variables
    leads          = os.getenv("FCSTLEADS")
    forecast_leads = leads.split()
    
    # Static variables
    pcp_var1 = ':NCPCP:'
    pcp_var2 = ':ACPCP:'

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
    init_file = 'ruc_%sz' % (date_str)
    
    # Have to get fancy with dates, since RUC wants day # of year
    ruc_ff = t.strftime('%y%j%H')
        
    for forecast_lead in forecast_leads:
        print forecast_lead

        # Get model data
        forecast_file = '%s0000%s' % (ruc_ff,forecast_lead)
        print forecast_file
        new_file = 'ruc_%sz+%s' % (date_str,forecast_lead)

        if (os.path.isfile('%s/%s.grib2' % (model_dir,forecast_file))):
            cmd = 'cp %s/%s.grib2 %s.grib2' % (model_dir,forecast_file,new_file)
            print cmd
            os.system(cmd)
            
            # Ungrib RUC file into NetCDF, remove grib2 file
            if (int(forecast_lead) == 0):
                start = int(forecast_lead)
            else:
                start = int(forecast_lead)-1
            end = int(forecast_lead)
            cmd = 'wgrib2 %s.grib2 | egrep "(%ssurface:%d-%d hour acc fcst:|%ssurface:%d-%d hour acc fcst:)" | wgrib2 -i %s.grib2 -netcdf %s.nc' %  \
                      (new_file,pcp_var1,start,end,pcp_var2,start,end,new_file,new_file)
            print cmd
            os.system(cmd)
            os.remove('%s.grib2' % new_file)

            # Now, call add_pcp to add together Non-convective and Convective Precipitation
            cmd = '%s/add_pcp %s.nc' % (exec_dir,new_file)
            print cmd
            os.system(cmd)
        else:
            print 'RUC forecast missing'

    # Add hourly precip totals
    cmd = 'cp %s+01.nc ruc_%sz_01hr_total.nc' % (init_file,date_str)
    print cmd
    os.system(cmd)

    cmd = '%s/add_hourly 1 3 1 %s ruc_%sz_03hr_total.nc false' % (exec_dir,init_file,date_str)
    print cmd
    os.system(cmd)

    cmd = '%s/add_hourly 1 6 1 %s ruc_%sz_06hr_total.nc false' % (exec_dir,init_file,date_str)
    print cmd
    os.system(cmd)

    cmd = '%s/add_hourly 1 12 1 %s ruc_%sz_12hr_total.nc false' % (exec_dir,init_file,date_str)
    print cmd
    os.system(cmd)
            
    os.chdir('..')

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
