# module get_model_file.py
import time
import os
from math import *

def get_model_file(model,run_time,fcst_len_mins):
    fcst_len = ceil(fcst_len_mins/60.)
    model_filename = None
    path_suffix =  time.strftime("%Y%m%d%H/postprd/", \
                                 time.gmtime(run_time))
    nco_path_suffix =  time.strftime("%Y%m%d/%H/", \
                                 time.gmtime(run_time))
    model_suffix =  "%02d" % (int(fcst_len))+".grib2"
    model_path = ""
    model_base = ""
    if model == "HRRR":
        model_path = "/home/rtrr/hrrr/"+path_suffix
        model_base = "wrftwo_subh_hrconus_"+model_suffix
    elif model == "HRRR_smoke":
        model_path = "/lfs1/BMC/amb-verif/HRRR-smoke/"+path_suffix
        model_base = "wrftwo_hrconus_"+model_suffix
    elif model == "HRRR_OPS":
        model_path = "/public/data/grids/hrrr/conus/wrfsfc/grib2/";
        model_base = time.strftime("%y%j%H", time.gmtime(run_time)) + \
            "%06d" % (int(fcst_len))
    elif model == "HRRR_WFIP2":
        fcst_len_hh = floor(fcst_len_mins/60.)
        fcst_len_mm = (((fcst_len_mins/60.)-(fcst_len_hh))*60.)
        path_suffix_wfip2 =  time.strftime("%Y%m%d%H/postprd/conus/", \
                                 time.gmtime(run_time))
        model_suffix_wfip2 =  "%02d" % (int(fcst_len_hh)) + "%02d" % (int(fcst_len_mm)) + ".grib2"
        model_path = "/home/rtrr/hrrr_wfip2_databasedir/run/"+path_suffix_wfip2
        model_base = "wrfnat_conus_"+model_suffix_wfip2
    elif model == "RAP_130":
        model_path = "/home/rtrr/rr/"+path_suffix
        if fcst_len == 0:
            model_suffix = "%02d" % (int(fcst_len))+".al00.grb2"
        model_base = "wrftwo_130_"+model_suffix
    elif model == "RAP_dev1":
        model_path = "/lfs1/BMC/amb-verif/RAPdev1/"+path_suffix
        if fcst_len == 0:
            model_suffix = "%02d" % (int(fcst_len))+".al00.grb2"
        model_base = "wrftwo_rr_"+model_suffix
    elif model == "RRFS_A":
        model_path = "/lfs4/BMC/rtwbl/mhu/wcoss/emc/rrfs/rrfs_a."+nco_path_suffix+"/"
        rrfs_suffix1 = time.strftime("RRFS_CONUS.t%Hz.", \
                                       time.gmtime(run_time))
        rrfs_suffix2 = "bgrd3df%03d" % (int(fcst_len))+".tm00.grib2"
        model_base = rrfs_suffix1+rrfs_suffix2
    elif model == "RRFS_B":
        model_path = "/lfs4/BMC/nrtrr/NCO_dirs/ptmp/com/RRFS_CONUS/para/RRFS_conus_3km."+nco_path_suffix+"/"
        rrfs_suffix1 = time.strftime("RRFS_CONUS.t%Hz.", \
                                       time.gmtime(run_time))
        rrfs_suffix2 = "bgrd3df%03d" % (int(fcst_len))+".tm00.grib2"
        model_base = rrfs_suffix1+rrfs_suffix2
    elif model == "RRFS_NA_3km_dev1_HRRR":
        model_path = "/lfs4/BMC/nrtrr/NCO_dirs/stmp/tmpnwprd/RRFS_NA_3km_dev1/"+path_suffix+"hrrr_grid/"
        rrfs_na_suffix1 = time.strftime("RRFS_NA_3km.t%Hz.", \
                                       time.gmtime(run_time))
        rrfs_na_suffix2 = "bgrd3df%03d" % (int(fcst_len))+".tm00.grib2"
        model_base = rrfs_na_suffix1+rrfs_na_suffix2
    elif model == "WRF_solar":
        model_path = "/misc/public/data/grids/ncar/wrf_solar/"
        model_base = time.strftime("wrfsolar_conus_d01_%Y-%m-%d", \
                                       time.gmtime(run_time))
    elif model == "RAP_OPS_130":
        model_path = "/public/data/grids/rap/hyb_130/grib2/";
        model_base = time.strftime("%y%j%H", time.gmtime(run_time)) + \
            "%06d" % (int(fcst_len))
    elif model == "HRRR_NREL":
        model_path = "/public/data/gsd/hrrr_nrel/conus/wrfnat/";
        model_base = time.strftime("%y%j%H", time.gmtime(run_time)) + \
            "%04d" % (int(fcst_len)) + "00"
    elif model == "NAM":
        model_path = "/public/data/grids/nam/nh221/grib2/";
        model_base = time.strftime("%y%j%H", time.gmtime(run_time)) + \
            "%06d" % (int(fcst_len))
    else:
        # assume its a retro run
        model_filename = None
        model_suffix =  "%02d" % (int(fcst_len))+".grib2"
        if model.endswith("coupled") == True:
            model_path = "./retro/"+model+time.strftime("/%Y%m%d%H_2WAY/postprd/",time.gmtime(run_time));
        else:
            model_path = "./retro/"+model+time.strftime("/%Y%m%d%H/postprd/",time.gmtime(run_time));
        model_base = ""
        if fcst_len == 0:
            model_suffix = "%02d" % (int(fcst_len))+".al00.grb2"
        if model.startswith("RAP") == True:
            model_base = "wrftwo_130_"+model_suffix
        elif model.startswith("HRRR") == True:
            model_base = "wrftwo_hrconus_"+model_suffix
        elif model.startswith("RRFSret_nwm") == True:
            model_base_tmp = time.strftime("rrfs.t%Hz.prslev", time.gmtime(run_time))
            model_base = "%sf%03d.tm00.grib2" % (model_base_tmp,int(fcst_len))
        else:
            model_base = "wrftwo_130_"+model_suffix
        model_filename = model_path + model_base


    model_filename = model_path + model_base
    print os.getpid(),"",model,"filename:",model_filename

    if not os.path.exists(model_filename):
        print os.getpid()," is missing\n"
        model_filename = None
        
    return(model_filename)

            
        
