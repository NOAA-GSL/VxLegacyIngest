#!/usr/bin/env python
###################
#
# Name: StageIV_init.py
#
# Description: script for moving StageIV grib2 files
#
#
# History:
#   INITIAL VERSION - Jeff Hamilton GSD/ADB, 20180404
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

    exec_dir   = os.getenv("EXECDIR")
    script_dir = os.getenv("SCRIPTDIR")
    rt_dir     = os.getenv("REALTIMEDIR")
    obs_dir    = os.getenv("OBSDIR")

    # Interpolation options

    pcp_mask = os.getenv("PCPMASK")

    # Static variables

    precip_file = 'stageIV_6hr_precip'

    # Move files

    time = datetime(int(Year),int(Month),int(Day),int(Hour))

    # Files named with reference time, so valid time is reference time plus forecast hour
    src_file = time.strftime('st4_conus.%Y%m%d%H.06h.grb2')

    # Construct valid dir under run dir
    valid_dir = time.strftime('%Y%m%d-%Hz')
    print(valid_dir)
    os.system('mkdir -p %s/%s' % (rt_dir,valid_dir))
    os.chdir('%s/%s' % (rt_dir,valid_dir))

    print('Source file: ', src_file)
    cmd = 'cp %s/%s %s.grib2' % (obs_dir,src_file,precip_file)
    print(cmd)
    os.system(cmd)

    if (os.path.isfile('%s.grib2' % precip_file)):
        print('StageIV file moved: %s.grib2' % precip_file)
    else:
        print('precip file missing')

####### main ##########

if __name__ == "__main__":
    main()
