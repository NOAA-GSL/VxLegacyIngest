#!/usr/bin/env python
#======================================================================================
# This script will first retrieve the NCWD files closest to the top of the hour and
# then retrieve the HRRR VIL and RADARVIL data from the 15 min output files
#
# By: Patrick Hofmann
# Last Update: 09 AUG 2010
#
# To execute: ./HRRRvNCWD_init_verif.py
#
# Example NCWD file: 1021721210000 --NetCDF files
# Recent (1-3 days) dir: /public/data/rtvs/grids/ncwf/255/netcdf
# Archive dir: ???
#
# Example HRRR file: 15min_d01_YYYY-MM-DD_HH:00:00 
# Recent (1-2 days) dir: /misc/whome/rtrr/hrrr/YYYYMMDDHH/wrfprd
# Archive dir: ???
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
    valid_time = os.getenv("HOUR")

    exec_dir   = os.getenv("EXECDIR")
    rt_dir     = os.getenv("REALTIMEDIR")
    obs_dir    = os.getenv("OBSDIR")
    model_dir  = os.getenv("MODELDIR")
    
    # Looping variables
    leads          = os.getenv("FCSTLEADS")
    forecast_leads = leads.split()
    
    # Static variables
    obs_grid = 'NCWD'

    #-----------------------------End of Definitions--------------------------------

    # First, set stacksize to 512MB
    resource.setrlimit(resource.RLIMIT_STACK,(1600000000,1600000000))
    
    # Construct valid dir under run dir
    valid_dir = '%4d%02d%02d-%02dz' % (int(Year),int(Month),int(Day),int(valid_time))
    print valid_dir
    os.chdir(rt_dir)
    os.system('mkdir %s' % valid_dir)
    os.chdir(valid_dir)

    # Retreive NCWD file closest to top of hour
    t = datetime(int(Year),int(Month),int(Day),int(valid_time))
    for i in range(0,3):
        delta_t = timedelta(minutes=int(i))
        hi_t = t + delta_t
        lo_t = t - delta_t
        hi_ncwd = '%s/%s0000' % (obs_dir,hi_t.strftime('%y%j%H%M'))
        lo_ncwd = '%s/%s0000' % (obs_dir,lo_t.strftime('%y%j%H%M'))
        print hi_ncwd
        print lo_ncwd
        if (os.path.isfile(hi_ncwd)):
            #cmd = 'cp %s ncwd_%4d%02d%02d%02dz.nc' % (hi_ncwd,t.year,t.month,t.day,t.hour)
            cmd = 'cp %s ncwd.nc' % (hi_ncwd)
            print cmd
            os.system(cmd)
            break
        if (os.path.isfile(lo_ncwd)):
            #cmd = 'cp %s ncwd_%4d%02d%02d%02dz.nc' % (lo_ncwd,t.year,t.month,t.day,t.hour)
            cmd = 'cp %s ncwd.nc' % (lo_ncwd)
            print cmd
            os.system(cmd)
            break

    for forecast_lead in forecast_leads:
        print forecast_lead
        delta_t = timedelta(hours=-int(forecast_lead))
        ff_t = t + delta_t

        ftime = '%4d%02d%02d%02d' % (ff_t.year,ff_t.month,ff_t.day,ff_t.hour)
        forecast_dir = '%s/%s/wrfprd' % (model_dir,ftime)

        src_fmt  = '15min_d01_%Y-%m-%d_%H:%M:%S'
        dest_fmt = '%y%j%H%M%f'

        cmd = "find -L %s -name '15min_d01*' | ~wrfruc/tmatch/ctime --wrf %s --from %s/%s --to %s --ln" % (forecast_dir,ftime,forecast_dir,src_fmt,dest_fmt)

        print cmd
        os.system(cmd)

        # HRRR 15min data is broken up into five 3-hour files
        if (int(forecast_lead) <= 3):
            hrfile = '03'
        if (int(forecast_lead) > 3 and int(forecast_lead) <= 6):
            hrfile = '06'
        if (int(forecast_lead) > 6 and int(forecast_lead) <= 9):
            hrfile = '09'
        if (int(forecast_lead) > 9 and int(forecast_lead) <= 12):
            hrfile = '12'
        if (int(forecast_lead) > 12 and int(forecast_lead) <= 15):
            hrfile = '15'

        # Get model data
        forecast_file = '%s%s' % (ff_t.strftime('%y%j%H%M'),hrfile)
        print forecast_file

        new_file = 'hrrr_%s%02d%02d%02dz+%s.nc' % (ff_t.year,ff_t.month,ff_t.day,ff_t.hour,forecast_lead)

        if (os.path.islink(forecast_file)):
            cmd = '%s/get_15min_hrrr %s %s %s' % (exec_dir,forecast_lead,forecast_file,new_file)
            print cmd
            os.system(cmd)
        else:
            print 'HRRR forecast missing'

    os.system('rm %s*' % (t.strftime('%y')))
    os.chdir('..')
    
#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
