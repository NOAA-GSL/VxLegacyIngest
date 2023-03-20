#!/usr/bin/env python
#======================================================================================
# This script will retrieve and ungrib NAM data for Precip verification
#
# By: Patrick Hofmann
# Last Update: 12 OCT 2011
#
# To execute: ./NAM_precip_init.py
#
# Example NAM file: 1128518000000
# Recent (1-2 days) dir: /public/data/grids/nam/A218/grib2 
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
    init_time  = os.getenv("HOUR")
    
    rt_dir     = os.getenv("REALTIMEDIR")
    model_dir  = os.getenv("MODELDIR")
    exec_dir   = os.getenv("EXECDIR")
    model      = os.getenv("MODEL")
    
    # Looping variables
    forecast_leads = (os.getenv("FCSTLEADS")).split()
    
    # Static variables
    pcp_var = 'APCP'
    
    #-----------------------------End of Definitions--------------------------------

    # Construct valid dir under run dir
    init_dir = '%s%s%s-%sz' % (Year,Month,Day,init_time)
    print init_dir

    if (not os.path.isdir('%s/%s' % (rt_dir,init_dir))):
        os.system('mkdir -p %s/%s' % (rt_dir,init_dir))
        
    os.chdir('%s/%s' % (rt_dir,init_dir))

    # Use built-in Date/Time modules
    t = datetime(int(Year),int(Month),int(Day),int(init_time))
        
    for forecast_lead in forecast_leads:
        print forecast_lead

        # Get model data
        nam_ff = t.strftime('%y%j%H')
        forecast_file = '%s0000%02d' % (nam_ff,int(forecast_lead))
        print forecast_file

        # Determine start and end forecast hours
        start = int(forecast_lead)-3
        end = int(forecast_lead)

        src_file = '%s/%s' % (model_dir,forecast_file)
        new_file = '%s_%4d%02d%02d%02dz_%02d-%02d_total' % (model,t.year,t.month,t.day,t.hour,start,end)
        print new_file

        if (os.path.isfile('%s' % (src_file))):
            # Ungrib NAM file into NetCDF, remove grib2 file
            cmd = 'wgrib2 %s | egrep "%s:surface:%d-%d hour acc fcst" | wgrib2 -i %s -netcdf %s.nc' %  \
                      (src_file,pcp_var,start,end,src_file,new_file)
            print cmd
            os.system(cmd)
        else:
            print 'NAM forecast missing'

    # Add hourly precip totals
    # 12Hr totals
    init_file = '%s_%4d%02d%02d%02dz' % (model,t.year,t.month,t.day,t.hour)
    cmd = '%s/add_hourly 0 9 3 %s %s_12hr_total.nc true' % (exec_dir,init_file,init_file)
    print cmd
    os.system(cmd)

    # 6Hr totals
    init_file = '%s_%4d%02d%02d%02dz' % (model,t.year,t.month,t.day,t.hour)
    cmd = '%s/add_hourly 0 3 3 %s %s_06hr_total.nc true' % (exec_dir,init_file,init_file)
    print cmd
    os.system(cmd)

    # 3Hr totals
    init_file = '%s_%4d%02d%02d%02dz' % (model,t.year,t.month,t.day,t.hour)
    cmd = 'cp %s_00-03_total.nc %s_03hr_total.nc' % (init_file,init_file)
    print cmd
    os.system(cmd)

    os.system('rm -rf *-*.nc')
            
    os.chdir('..')

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
