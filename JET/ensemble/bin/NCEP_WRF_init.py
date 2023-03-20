#!/usr/bin/env python
###################
#
# Name: NCEP_WRF_init.py
#
# Description: script for moving NCEP WRF grib2 files
#
#
# History:
#   INITIAL VERSION - Jeff Hamilton GSD/ADB, 20180406
#
###################
import sys
import os
import resource
from datetime import datetime
from datetime import timedelta

def main():
    # Environmental options
    Year = os.getenv("YEAR")
    Month = os.getenv("MONTH")
    Day = os.getenv("DAY")
    Hour = os.getenv("HOUR")

    exec_dir = os.getenv("EXECDIR")
    script_dir = os.getenv("SCRIPTDIR")
    rt_dir = os.getenv("REALTIMEDIR")
    model_dir = os.getenv("MODELDIR")
    model = os.getenv("MODEL")

    # Looping variables

    variables = (os.getenv("VARIABLE")).split(", ")
    forecast_leads = (os.getenv("FCSTLEADS")).split()

    # Interpolation options

    #pcp_mask = os.getenv("PCPMASK")


    # Move files

    time = datetime(int(Year), int(Month), int(Day), int(Hour))

    date_str = '%4d%02d%02d%02d' % (time.year, time.month, time.day, time.hour)

    # Create realtime directory

    valid_dir = time.strftime('%Y%m%d-%Hz')
    print(valid_dir)
    os.system('mkdir -p %s/%s' % (rt_dir, valid_dir))
    os.chdir('%s/%s' % (rt_dir, valid_dir))

    for fcst_len in forecast_leads:
        src_file_str = time.strftime('%y%j%H')
        src_file = '%s0000%s' % (src_file_str,fcst_len)

        new_file = '%s_%s_%s.grib2' % (model,date_str,fcst_len)
        file_created = False

        # Move files

        fcst_file = '%s/%s' % (model_dir,src_file)

        if (os.path.isfile('%s' % fcst_file)):

            print('Source file: ', src_file)

            for var in variables:
            # Grab only the variable desired
               if (os.path.isfile('%s' % new_file) and file_created is True):
                  cmd = 'wgrib2 %s | egrep "(%s)" | wgrib2 -i %s -append -GRIB %s' % (fcst_file,var,fcst_file,new_file)
               else:
                  cmd = 'wgrib2 %s | egrep "(%s)" | wgrib2 -i %s -GRIB %s' % (fcst_file,var,fcst_file,new_file)
                  file_created = True
               print(cmd)
               os.system(cmd)

            if (os.path.isfile('%s' % new_file)):
                print('%s file moved to %s/%s/%s' % (fcst_file,rt_dir,valid_dir,new_file))
            else:
                print('%s file missing' % (new_file))

        else:
            print('%s file missing' % (fcst_file))

####### main ##########

if __name__ == "__main__":
    main()
