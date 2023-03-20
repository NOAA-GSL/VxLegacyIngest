#!/usr/bin/env python
#======================================================================================
# This script will copy GRIB1 files to GRIB2 format
#
# By: Eric James
# Last Update: 25 MAR 2015
#
# To execute: ./cnvgrib.py
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
    
    model_dir  = os.getenv("MODELDIR")
    dest_dir   = os.getenv("DESTDIR")
    exec_dir   = os.getenv("EXECDIR")
    
    # Looping variables
    forecast_leads = (os.getenv("FCSTLEADS")).split()
    
    #-----------------------------End of Definitions--------------------------------

    # First, set stacksize to 512MB
    # resource.setrlimit(resource.RLIMIT_STACK,(800000000,800000000))
    
    # CD to dest_dir
    os.chdir(dest_dir)

    # Use built-in Date/Time modules
    t = datetime(int(Year),int(Month),int(Day),int(init_time))
    
    # files are formatted as: YYDDDHH0000FF
    ruc_ff = t.strftime('%y%j%H')
        
    for forecast_lead in forecast_leads:
        print forecast_lead

        # Get model data
        forecast_file = '%s0000%s' % (ruc_ff,forecast_lead)
        print forecast_file

        # Convert to GRIB2
        cmd = '%s/cnvgrib.exe -g12 -p32 %s/%s %s/%s' % (exec_dir,model_dir,forecast_file,dest_dir,forecast_file)
        print cmd
        os.system(cmd)

    os.chdir('..')

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
