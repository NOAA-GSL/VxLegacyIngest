#!/usr/bin/env python
###################
#
# Name: GSD_ensemble_init_rt.py
#
# Description: realtime script for moving GSL ensemble member grib2 files
#
#
# History:
#   INITIAL VERSION - Jeff Hamilton GSL/AVID, 20210518
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
    regions = (os.getenv("REGIONS")).split()
    members = (os.getenv("MEMBERS")).split()
    member_dirs = (os.getenv("MEMBER_DIRS")).split()

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
     delta_t = timedelta(hours=int(fcst_len))
     valid = time + delta_t        
     valid_dir = valid.strftime('%Y%m%d-%Hz')
     valid_str = '%4d%02d%02d%02d' % (valid.year, valid.month, valid.day, valid.hour)
     print(valid_dir)
     os.system('mkdir -p %s/%s' % (rt_dir, valid_dir))
     os.chdir('%s/%s' % (rt_dir, valid_dir))
     for (member,member_dir) in zip(members,member_dirs):
        if (model == "hrrre"):
           fcst_dir = '%s/%s/%s' % (model_dir,date_str,member_dir)
        elif (model == "rrfse"):
           fcst_dir = '%s/%4d%02d%02d/%02d/%s' % (model_dir,time.year,time.month,time.day,time.hour,member_dir)

        # grab each region

        for reg in regions:

            if (model == "hrrre"):
               src_file = 'wrftwo_%s_mem000%s_%s.grib2' % (reg,member,fcst_len)
            elif (model == "rrfse"):
               src_file = 'RRFS_CONUS.t%02dz.bgsfcf0%s.tm00.grib2' % (time.hour,fcst_len)

            new_file = '%s_mem%s_%s_%s_%s.grib2' % (model,member,valid_str,reg,fcst_len)

            # Move files

            fcst_file = '%s/%s' % (fcst_dir,src_file)

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