#!/usr/bin/env python
#=======================================================================================
# This script will retrieve all the HRRRE data necessary for PRECIP verification.
#
# By: Jeff Hamilton
# Last Update: 2 Mar 2017
#
# To execute: ./HRRRE_init_precip_verif.py
#
# Example HRRRE file: wrftwo_conus_mem0001_FF.grib2
# Recent (1-2 days) dir: /lfs3/projects/wrfruc/HRRRE/forecast/YYYYMMDDHH/postprd_mem000#/
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
    
    # Looping variables
    forecast_leads = (os.getenv("FCSTLEADS")).split()
    members = (os.getenv("ENSEMBLE_MEMBERS")).split()
    
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
   
    for member in members: 
      for forecast_lead in forecast_leads:
        print forecast_lead
    
        # Get model data
        forecast_dir = '%s/%s/postprd_mem000%s' % (model_dir,date_str,member)
        print forecast_dir
        forecast_file = '%s/wrftwo_conus_mem000%s_%s.grib2' % (forecast_dir,member,forecast_lead)
        print forecast_file
        new_file = 'hrrre_mem%s_%sz_%shr_total.nc' % (member,date_str,forecast_lead)
        print new_file

        if (os.path.isfile('%s' % forecast_file)):
            # Extract precip field from HRRRE file into NetCDF
            start = 0
            end = int(forecast_lead)
            cmd = 'wgrib2 %s | egrep "(%s:surface:%d-%d hour acc fcst:)" | wgrib2 -i %s -netcdf %s' %  \
                  (forecast_file,pcp_var,start,end,forecast_file,new_file)
            print cmd
            os.system(cmd)
        else:
            print 'HRRRE forecast missing'

    os.chdir('..')

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
