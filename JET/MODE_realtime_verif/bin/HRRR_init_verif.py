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

    model_dir  = os.getenv("DATA_DIR")
    
    # Looping variables
    forecast_leads = (os.getenv("FCSTLEADS")).split()
    
    # Static variables
    pcp_var = 'APCP'
    cref_var = 'REFC'

    #-----------------------------End of Definitions--------------------------------

    # Use built-in Date/Time modules
    t = datetime(int(Year),int(Month),int(Day),int(init_time))

    date_str = '%4d%02d%02d%02d' % (t.year,t.month,t.day,t.hour)
   
    # files are formatted as: YYDDDHH0000FF
    ruc_ff = t.strftime('%y%j%H')
 
    for forecast_lead in forecast_leads:
        print forecast_lead
    
        forecast_file = '%s/%s0000%s' % (model_dir,ruc_ff,forecast_lead)
        print forecast_file
        
        new_file = '%s_%s.grib2' % (date_str,forecast_lead)
        print new_file

        if (os.path.isfile('%s' % forecast_file)):
            # Extract precip field from HRRR file
            cmd = 'wgrib2 %s | egrep "(%s)" | wgrib2 -i %s -GRIB %s' % (forecast_file,pcp_var,forecast_file,new_file)
            print cmd
            os.system(cmd)
            cmd = 'wgrib2 %s | egrep "(%s)" | wgrib2 -i %s -append -GRIB %s' % (forecast_file,cref_var,forecast_file,new_file)
            print cmd
            os.system(cmd)
        else:
            print '%s forecast missing' % forecast_lead

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
