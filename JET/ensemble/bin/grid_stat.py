#!/usr/bin/env python
###################
#
# Name: grid_stat.py
#
# Description: script for gathering proper files and running MET Grid Stat
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
    obs_dir = os.getenv("OBSDIR")
    model_dir = os.getenv("MODELDIR")
    model = os.getenv("MODEL")
    cfg_file = os.getenv("CFGFILE")
    fcst_len = os.getenv("FCSTLEN")
    region = os.getenv("REGION")

    hdf5 = os.getenv("HDF5_DISABLE_VERSION_CHECK")

    print("HDF_VERSION_CHECK = " + str(hdf5))
    # Find obs file

    time = datetime(int(Year), int(Month), int(Day), int(Hour))

    obs_date_str = '%4d%02d%02d%02d' % (time.year, time.month, time.day, time.hour)
    obs_valid_str = time.strftime('%Y%m%d-%Hz')

    obs_dir_str = '%s/%s' % (obs_dir,obs_valid_str)

    obs_file = '%s/stageIV_6hr_precip.grib2' % (obs_dir_str)

    print('Valid Time: ',obs_date_str)

    # Find model file

    delta_time = timedelta(hours=int(fcst_len))

    cycle_time = time - delta_time

    model_date_str = '%4d%02d%02d%02d' % (cycle_time.year, cycle_time.month, cycle_time.day, cycle_time.hour)
    model_valid_str = cycle_time.strftime('%Y%m%d-%Hz')

    model_dir_str = '%s/%s' % (model_dir, model_valid_str)

    if (region is None):
    	model_file = '%s/%s_%s_%s.grib2' % (model_dir_str,model,model_date_str,fcst_len)
    else:
    	model_file = '%s/%s_%s_%s_%s.grib2' % (model_dir_str,model,model_date_str,region,fcst_len)

    print('Cycle Time: ', obs_date_str)

    # Create realtime directory

    valid_dir = time.strftime('%Y%m%d-%Hz')
    final_dir = '%s/%s/grid_stat' % (rt_dir, valid_dir)
    print(final_dir)
    os.system('mkdir -p %s' % (final_dir))

    # Run MET Grid Stat
    
    cmd = '%s/grid_stat %s %s %s -outdir %s' % (exec_dir,model_file,obs_file,cfg_file,final_dir)
    print(cmd)
    os.system(cmd)

####### main ##########

if __name__ == "__main__":
    main()
