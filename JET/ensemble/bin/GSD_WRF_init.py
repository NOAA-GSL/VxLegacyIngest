#!/usr/bin/env python
###################
#
# Name: GSD_WRF_init.py
#
# Description: script for moving GSD WRF grib2 files
#
#
# History:
#   INITIAL VERSION - Jeff Hamilton GSD/ADB, 20180405
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
    var = os.getenv("VARIABLE")

    # Looping variables

    forecast_leads = (os.getenv("FCSTLEADS")).split()
    regions = (os.getenv("REGIONS")).split()

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

        fcst_dir = '%s/%s/postprd_ensprod' % (model_dir,date_str)

        # grab each region

        for reg in regions:

            src_file = 'wrftwo_%s_ensprod_%s.grib2' % (reg,fcst_len)

            new_file = '%s_%s_%s_%s.grib2' % (model,date_str,reg,fcst_len)

            # Move files

            fcst_file = '%s/%s' % (fcst_dir,src_file)

            if (os.path.isfile('%s' % fcst_file)):

                print('Source file: ', src_file)

                # Grab only the variable desired

                cmd = 'wgrib2 %s | egrep "(%s)" | wgrib2 -i %s -GRIB %s' % (fcst_file,var,fcst_file,new_file)
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
