#!/usr/bin/env python
#======================================================================================
# This script will retrieve the grib2 NSSL mosaic file and then interpolate the 1km
# grid into all the necessary scales, along with plot each field.
#
# By: Jeff Hamilton
# Last Update: 20 DEC 2016
#
# To execute: ./NSSL_interp_new.py
#
# Example NSSL file: 
#
#---------------------------------------start-------------------------------------------
import sys
import os
import resource
from datetime import datetime
from datetime import timedelta
import subprocess
import fnmatch

def main():
    Year       = os.getenv("YEAR")
    Month      = os.getenv("MONTH")
    Day        = os.getenv("DAY")
    valid_time = os.getenv("HOUR")

    exec_dir   = os.getenv("EXECDIR")

    script_dir = os.getenv("SCRIPTDIR")
    nssl_dir   = os.getenv("REALTIMEDIR")
    obs_dir    = os.getenv("OBSDIR")
   
    nssl_var    = os.getenv("NSSLVAR") 
    grib2_var   = os.getenv("GRIB2VAR") 
    
    # Static variables
    
    mosaic_file = 'mrms_mosaic'
    
    #-----------------------------End of Definitions--------------------------------

    # First, set stacksize to 800MB
    resource.setrlimit(resource.RLIMIT_STACK,(1600000000,1600000000))

    # Construct valid dir under run dir
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,valid_time)
    print valid_dir
    if (not os.path.isdir('%s/%s' % (nssl_dir,valid_dir))):
        os.mkdir('%s/%s' % (nssl_dir,valid_dir))
    os.chdir('%s/%s' % (nssl_dir,valid_dir))

    # Retrieve grib2 file and convert to netcdf
    grib_search = '%s%s%s-%s*.MRMS_%s_00.50_%s%s%s-%s*.grib2' % (Year,Month,Day,valid_time,nssl_var,Year,Month,Day,valid_time)
    cmd = 'ls %s/%s' % (obs_dir,grib_search)
    print cmd
    grib = find(grib_search,obs_dir)
    print grib

    print grib
    cmd = 'cp %s %s.grib2' % (grib,mosaic_file)
    print cmd
    os.system(cmd)
    cmd = 'wgrib2 %s.grib2 | egrep "(%s)" | wgrib2 -i %s.grib2 -netcdf %s.nc' % (mosaic_file,grib2_var,mosaic_file,mosaic_file)
    print cmd
    os.system(cmd)
        
#-------------- find ----------------

def find(pattern, path):
    result = []
    for root, dirs, files in os.walk(path):
        for name in files:
            if fnmatch.fnmatch(name, pattern):
                result.append(os.path.join(root, name))
    return result[0]

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
