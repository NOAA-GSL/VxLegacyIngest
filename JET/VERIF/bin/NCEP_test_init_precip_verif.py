#!/usr/bin/env python
#=======================================================================================
# This script will retrieve all the HRRR/RAP data necessary for PRECIP verification.
#
# By: Patrick Hofmann
# Last Update: 17 SEP 2012
#
# To execute: ./WRF_init_precip_verif.py
#
# Example HRRR file: wrftwo_hrconus_FF.grib2
# Recent (1-2 days) dir: /misc/whome/rtrr/hrrr/YYYYMMDDHH/postprd/
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
    exec_dir   = os.getenv("EXECDIR")
    model_dir  = os.getenv("MODELDIR")
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

    date_str = '%4d%02d%02d%02d' % (t.year,t.month,t.day,t.hour)
   
    # files are formatted as: YYDDDHH0000FF
    ruc_ff = t.strftime('%y%j%H')
 
    for forecast_lead in forecast_leads:
        print forecast_lead
    
        # Get model data
        #forecast_dir = '%s/%s/postprd' % (model_dir,date_str)
        #print forecast_dir
 
        forecast_file = '%s/%s0000%s' % (model_dir,ruc_ff,forecast_lead)
        print forecast_file
        
        new_file = '%s_%sz_%shr_total.nc' % (model,date_str,forecast_lead)
        print new_file

        if (os.path.isfile('%s' % forecast_file)):
            # Extract precip field from HRRR file into NetCDF
            start = 0
            end = int(forecast_lead)
            if (forecast_lead == '24'):
                cmd = 'wgrib2 %s | egrep "(%s:surface:0-1 day acc fcst:)" | wgrib2 -i %s -netcdf %s' % \
                      (forecast_file,pcp_var,forecast_file,new_file)
            else:
                cmd = 'wgrib2 %s | egrep "(%s:surface:%d-%d hour acc fcst:)" | wgrib2 -i %s -netcdf %s' %  \
                      (forecast_file,pcp_var,start,end,forecast_file,new_file)
            print cmd
            os.system(cmd)
        else:
            print '%s forecast missing' % model

    os.chdir('..')

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
