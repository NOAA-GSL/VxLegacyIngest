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
    rrfs_type  = os.getenv("RRFS_TYPE")
    
    # Looping variables
    forecast_leads = (os.getenv("FCSTLEADS")).split()
    
    # Static variables
    pcp_var = 'APCP'
    cref_var = 'REFC'

    #-----------------------------End of Definitions--------------------------------

    # Use built-in Date/Time modules
    t = datetime(int(Year),int(Month),int(Day),int(init_time))

    date_str = '%4d%02d%02d%02d' % (t.year,t.month,t.day,t.hour)
   
    for forecast_lead in forecast_leads:
        print forecast_lead
    
        if (rrfs_type == "RRFS_NA_3km"):
            forecast_dir = '%s/rrfs_a.%s%02d%02d/%02d' % (model_dir,t.year,t.month,t.day,t.hour)
            forecast_file = '%s/rrfs.t%02dz.prslev.f%03d.conus_3km.grib2' % (forecast_dir,t.hour,int(forecast_lead))       
            new_file = '%s_%s.grib2' % (date_str,forecast_lead)
        if (rrfs_type == "RRFS_A"):
            forecast_dir = '%s/rrfs_a.%s%02d%02d/%02d' % (model_dir,t.year,t.month,t.day,t.hour)
            forecast_file = '%s/RRFS_CONUS.t%02dz.bgsfcf%03d.tm00.grib2' % (forecast_dir,t.hour,int(forecast_lead))
            new_file = '%s_%s.grib2' % (date_str,forecast_lead)
        if (rrfs_type == "RRFS_B"):
            forecast_dir = '%s/RRFS_conus_3km.%s%02d%02d/%02d' % (model_dir,t.year,t.month,t.day,t.hour)
            forecast_file = '%s/RRFS_CONUS.t%02dz.bgsfcf%03d.tm00.grib2' % (forecast_dir,t.hour,int(forecast_lead))
            new_file = '%s_%s.grib2' % (date_str,forecast_lead)
        if (rrfs_type == "RRFSE"):
            member = os.getenv("MEMBER")
            forecast_dir = '%s/RRFS_conus_3km.%s%02d%02d/%02d/mem00%02d' % (model_dir,t.year,t.month,t.day,t.hour,int(member))
            forecast_file = '%s/RRFS_CONUS.t%02dz.bgdawpf%03d.tm00.grib2' % (forecast_dir,t.hour,int(forecast_lead))
            new_file = '%s_%s_mem%s.grib2' % (date_str,forecast_lead,member)
        print forecast_file
        print new_file

        if (os.path.isfile('%s' % forecast_file)):
            # Extract precip field from RRFS file
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
