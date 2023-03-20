#!/usr/bin/env python
###################
#
# Name: gaussian_regrid.py
#
# Description: script for running the MAXGAUSS regrid option in MET's regrid-data-plane tool. This funtionality
# is not available in METplus yet, but as soon as it is this script will not be necessary
#
#
# History:
#   INITIAL VERSION - Jeff Hamilton GSD/ADB, 20200526
#
###################
import sys
import os
import math
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
    fcst_len = os.getenv("FCSTLEN")
    var = os.getenv("VAR")
    dx = os.getenv("DX")
    radius = os.getenv("RADIUS")
    neighborhood = os.getenv("NEIGHBORHOOD")
    level = os.getenv("LEVEL")

    hdf5 = os.getenv("HDF5_DISABLE_VERSION_CHECK")

    print("HDF_VERSION_CHECK = " + str(hdf5))

    # Convert neighborhood to neighborhood radius

    neighborhood_radius = math.sqrt(int(neighborhood))

    # See if it is a precip variable

    if(var == "APCP"):
      var = "%s_%s" % (var,fcst_len)
      level = "%s%d" % (level,int(fcst_len))

    # Find obs file

    time = datetime(int(Year), int(Month), int(Day), int(Hour))

    date_str = '%4d%02d%02d%02d' % (time.year, time.month, time.day, time.hour)
    valid_str = time.strftime('%Y%m%d-%Hz')

    dir_str = '%s/%s' % (rt_dir,valid_str)

    if("APCP" in var):
      obs_file = '%s/stageIV_%shr_precip.nc' % (dir_str,fcst_len)
      new_obs_file = '%s/stageIV_%shr_precip_G%s_N%s.nc' % (dir_str,fcst_len,radius,neighborhood)
    if(var == "var209_10_0_500mabovemeansealevel"):
      obs_file = '%s/mrms_mosaic_interp.nc' % (dir_str)
      new_obs_file = '%s/mrms_mosaic_G%s_N%s.nc' % (dir_str,radius,neighborhood)

    print('Valid Time: ',date_str)
    print('var: ',var)
    print('obs_file: ',obs_file)
    print('new_obs_file: ',new_obs_file)

    # Run MET Regrid Data Plane 
    
    cmd = """%s/bin/regrid_data_plane -v 2 -field 'name="%s"; level="%s";' -method MAXGAUSS -gaussian_dx %s -gaussian_radius %s -shape CIRCLE -width %d -vld_thresh 0.01 -name %s %s ""/home/amb-verif/ensemble/static/hrrre_3km_ref.grib2"" %s""" % (met_dir,var,level,dx,radius,int(neighborhood_radius),var,obs_file,new_obs_file)
    print(cmd)
    os.system(cmd)

####### main ##########

if __name__ == "__main__":
    main()
