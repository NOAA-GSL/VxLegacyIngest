# module get_model_file.py
import time
import os
from math import *

def get_model_file(model,run_time,fcst_len_mins):
    fcst_len = ceil(fcst_len_mins/60.)
    model_filename = None
    path_suffix =  time.strftime("%Y%m%d%H/postprd/", \
                                 time.gmtime(run_time))
    model_suffix =  "%02d" % (int(fcst_len))+".grib2"
    model_path = ""
    model_base = ""
    if model == "HRRR":
        model_path = "/home/rtrr/hrrr/"+path_suffix
        model_base = "wrftwo_subh_hrconus_"+model_suffix
    elif model == "HRRR_OPS":
        model_path = "/pan2/projects/public/data/grids/hrrr/conus/wrfnat/grib2/"
        model_base = time.strftime("%y%j%H", time.gmtime(run_time)) + \
            "%06d" % (int(fcst_len))
    elif model == "RAP_130":
        model_path = "/home/rtrr/rr/"+path_suffix
        if fcst_len == 0:
            model_suffix = "%02d" % (int(fcst_len))+".al00.grb2"
        model_base = "wrftwo_130_"+model_suffix
    elif model == "WRF_solar":
        model_path = "/public/data/grids/ncar/wrf_solar/"
        model_base = time.strftime("wrfsolar_conus_d01_%Y-%m-%d_00-00-00", \
                                       time.gmtime(run_time))
    elif model == "RAP_OPS_130":
        model_path = "/public/data/grids/rr/hyb_130/grib2/";
        model_base = time.strftime("%y%j%H", time.gmtime(run_time)) + \
            "%06d" % (int(fcst_len))

    model_filename = model_path + model_base
    print os.getpid(),"",model,"filename:",model_filename

    if not os.path.exists(model_filename):
        print os.getpid()," is missing\n"
        model_filename = None
        
    return(model_filename)

            
        
