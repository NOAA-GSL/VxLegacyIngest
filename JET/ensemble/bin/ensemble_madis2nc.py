#!/usr/bin/env python
###################
#
# Name: esnemble_madis2nc.py
#
# Description: script for converting madis files to MET netCDF files
#
#
# History:
#   INITIAL VERSION - Jeff Hamilton GSD/ADB, 20191022
#
###################
import sys
import os
import resource
from datetime import datetime
from datetime import timedelta

def main():
    # Environmental options
    Year       = os.getenv("YEAR")
    Month      = os.getenv("MONTH")
    Day        = os.getenv("DAY")
    Hour       = os.getenv("HOUR")

    met_dir   = os.getenv("MET_DIR")
    rt_dir     = os.getenv("REALTIMEDIR")
    obs_dir    = os.getenv("OBSDIR")
    obs        = os.getenv("NETWORK")

    # Define MADIS2NC executable

    madis2nc_ex = "%s/bin/madis2nc -v 2" % (met_dir)

    # Move files

    time = datetime(int(Year),int(Month),int(Day),int(Hour))
    date_str = '%4d%02d%02d%02d' % (time.year, time.month, time.day, time.hour)

    # Files named with reference time, so valid time is reference time plus forecast hour
    src_file = time.strftime('%Y%m%d_%H00')
    final_file = '%s_%s.nc' % (obs,date_str)

    # Construct valid dir under run dir
    valid_dir = time.strftime('%Y%m%d-%Hz')
    print(valid_dir)
    os.system('mkdir -p %s/%s' % (rt_dir,valid_dir))
    os.chdir('%s/%s' % (rt_dir,valid_dir))

    print('Source file: ', src_file)
    cmd = '%s %s/%s %s -type %s' % (madis2nc_ex,obs_dir,src_file,final_file,obs)
    print(cmd)
    os.system(cmd)

    if (os.path.isfile('%s' % final_file)):
        print('%s file created: %s' % (obs,final_file))
    else:
        print('%s file missing' % obs)

####### main ##########

if __name__ == "__main__":
    main()
