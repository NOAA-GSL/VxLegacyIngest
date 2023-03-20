# module get_model_file.py
import time
import os
from math import *

def get_model_file(model,run_time,fcst_len_mins):
    fcst_len = ceil(fcst_len_mins/60.)
    model_filename = None
    path_suffix =  time.strftime("%Y%m%d%H/postprd/", \
                                 time.gmtime(run_time))
    path_suffix2 =  time.strftime("%Y%m%d/%H/", \
                                 time.gmtime(run_time))
    hour =  time.strftime("%H", \
                                 time.gmtime(run_time))
    model_suffix =  "%02d" % (int(fcst_len))+".grib2"
    model_path = ""
    model_base = ""
    if model == "HRRR" or model == "HRRR2":
        model_path = "/home/rtrr/hrrr/"+path_suffix
        model_base = "wrftwo_subh_hrconus_"+model_suffix
    elif model == "RRFS_B":
        model_path = "/lfs4/BMC/nrtrr/NCO_dirs/ptmp/com/RRFS_CONUS/para/RRFS_conus_3km."+path_suffix2
        model_base = "RRFS_CONUS.t%02dz.bgsfcf%03d.tm00.grib2" % (int(hour),int(fcst_len))
    elif model == "NAMnest_OPS_227":
        model_path = "/public/data/grids/nam/conusnest/grib2/"
        model_base = time.strftime("%g%j%H000",time.gmtime(run_time)) + \
            "%03d" % (int(fcst_len))
    else:
        if model == "RAP_130":
            model_path = "/home/rtrr/rr/"+path_suffix
            if fcst_len == 0:
                model_suffix = "%02d" % (int(fcst_len))+".al00.grb2"
            model_base = "wrftwo_130_"+model_suffix

    model_filename = model_path + model_base
    print os.getpid(),"",model,"filename:",model_filename

    if not os.path.exists(model_filename):
        print os.getpid()," is missing\n"
        model_filename = None
        
    return(model_filename)

            
        
