#!/usr/bin/env python
###################
#
# Name: ensemble_pcp_combine.py
#
# Description: script for combining EMC bucket precip accumulations
#
#
# History:
#   INITIAL VERSION - Jeff Hamilton GSD/ADB, 20190915
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

    met_dir = os.getenv("MET_DIR")
    rt_dir = os.getenv("REALTIMEDIR")
    var = os.getenv("VARIABLE")
    model = os.getenv("MODEL")
    points = os.getenv("POINTS")
    neighborhood = os.getenv("neighborhood")

    # Looping variables

    fcst_lens = (os.getenv("FCSTLEADS")).split()

    # Define PCP Combine executable

    pcp_combine_ex = "%s/bin/pcp_combine -v 2" % (met_dir)

    time = datetime(int(Year), int(Month), int(Day), int(Hour))

    date_str = '%4d%02d%02d%02d' % (time.year, time.month, time.day, time.hour)

    # Create realtime directory

    valid_dir = time.strftime('%Y%m%d-%Hz')
    print(valid_dir)
    os.system('mkdir -p %s/%s' % (rt_dir, valid_dir))
    os.chdir('%s/%s' % (rt_dir, valid_dir))

    for fcst_len in fcst_lens:
    
       fcst_file = '%s_%s_%s.grib2' % (model,date_str,fcst_len)
       final_file = '%s_%s_%s.nc' % (model,date_str,fcst_len)

       # Convert all files less than 4 forecast hours for NMMB and NAM_NEST. Combine all after
       if model == "hrw_nmmb" or model == "nam_nest":

          if (int(fcst_len) < 4):
          
             cmd = "%s -name %s -add %s %s %s" % (pcp_combine_ex,var,fcst_file,str(fcst_len),final_file)
             print(cmd)
             os.system(cmd)

          else:

             int_fcst_len = int(fcst_len) % int(interval)
          
             if (int(int_fcst_len) == 0):
                int_fcst_len = 3

             pre_fcst_len = int(fcst_len) - int_fcst_len

             pre_fcst_file = '%s_%s_%02d.nc' % (model,date_str,pre_fcst_len)

             cmd = "%s -name %s -add %s %s %s %s %s" % (pcp_combine_ex,var,pre_fcst_file,str(pre_fcst_len),fcst_file,str(int_fcst_len),final_file)
             print(cmd)
             os.system(cmd)

       # Convert all grib2 files to NetCDF so that MET can read all members
       else:

          cmd = "%s -name %s -add %s %s %s" % (pcp_combine_ex,var,fcst_file,str(fcst_len),final_file)
          print(cmd)
          os.system(cmd)

####### main ##########

if __name__ == "__main__":
    main()
