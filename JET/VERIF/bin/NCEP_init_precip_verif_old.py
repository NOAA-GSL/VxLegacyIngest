#!/usr/bin/env python
#======================================================================================
# This script will first retrieve and ungrib all the RUC data for Precip verification
#
# By: Patrick Hofmann
# Last Update: 08 OCT 2010
#
# To execute: ./EMC_init_cref_verif.py
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
    model      = os.getenv("MODEL")
    
    # Looping variables
    forecast_leads = (os.getenv("FCSTLEADS")).split()
    
    # Static variables
    pcp_var1 = ':NCPCP:'
    pcp_var2 = ':ACPCP:'

    #-----------------------------End of Definitions--------------------------------

    # First, set stacksize to 512MB
    # resource.setrlimit(resource.RLIMIT_STACK,(800000000,800000000))
    
    # Construct valid dir under run dir
    init_dir = '%s%s%s-%sz' % (Year,Month,Day,init_time)
    print init_dir
    os.chdir(rt_dir)
    os.system('mkdir -p %s' % init_dir)
    os.chdir(init_dir)

    # Use built-in Date/Time modules
    t = datetime(int(Year),int(Month),int(Day),int(init_time))
    
    # files are formatted as: YYDDDHH0000FF
    ruc_ff = t.strftime('%y%j%H')
        
    for forecast_lead in forecast_leads:
        print forecast_lead

        # Get model data
        forecast_file = '%s0000%s' % (ruc_ff,forecast_lead)
        print forecast_file

        # Determine start and end forecast hours
        if (int(forecast_lead) == 1):
            start = int(forecast_lead)-1
            end = int(forecast_lead)
        else:
            start = int(forecast_lead)-3
            end = int(forecast_lead)
            
        new_file = '%s_%4d%02d%02d%02dz_%02d-%02d_total' % (model,t.year,t.month,t.day,t.hour,start,end)
        print new_file
        
        if (os.path.isfile('%s/%s' % (model_dir,forecast_file))):
            cmd = 'cp %s/%s %s.grib2' % (model_dir,forecast_file,new_file)
            print cmd
            os.system(cmd)
            
            # Ungrib RUC file into NetCDF, remove grib2 file
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
            print 'model forecast missing'

    # Add hourly precip totals
    init_file = '%s_%4d%02d%02d%02dz' % (model,t.year,t.month,t.day,t.hour)
    
    # 12Hr totals  
    cmd = '%s/add_hourly 0 9 3 %s %s_12hr_total.nc true' % (exec_dir,init_file,init_file)
    print cmd
    os.system(cmd)

    # 6Hr totals
    cmd = '%s/add_hourly 0 3 3 %s %s_06hr_total.nc true' % (exec_dir,init_file,init_file)
    print cmd
    os.system(cmd)

    # 3Hr totals
    cmd = 'mv %s_00-03_total.nc %s_03hr_total.nc' % (init_file,init_file)
    print cmd
    os.system(cmd)

    # 1Hr total
    cmd = 'mv %s_00-01_total.nc %s_01hr_total.nc' % (init_file,init_file)
    print cmd
    os.system(cmd)

    os.system('rm -rf *-*.nc')
            
    os.chdir('..')

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
