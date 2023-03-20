# module read_model.py
import time 
import pygrib
#from netCDF4 import Dataset
import os
import sys
from numpy import *
import struct
import time
from get_model_file import *
from Projection import *

def read_model2(model,run_time,fcst_len_mins):
    pid = os.getpid()
    start_time = time.time()
    good = True
    MODEL_filename = get_model_file(model,run_time,fcst_len_mins)
    if MODEL_filename is None:
        print "file is missing"
        good=False
        return(good,None,None,None,None)
    # now process the file
    print('model filename is '+MODEL_filename)
    grbs2 = pygrib.open(MODEL_filename)
    for grb in grbs2:
        lats,lons = grb.latlons()
        #print 'shape',lats.shape
        #print 'lats',lats[0:3,0:3]
        #print 'lons',lons[0:3,0:3]
        break
    #print('Hamilton testing')
    #selected_gribs=grbs2.select(name='Downward short-wave radiation flux')
    #for grb in selected_gribs:
    #    print(grb)
    # below shows how to get a list of all key/value pairs.
    # xue
#    for grb in grbs2:
#        print(grb)
    

    if False:
     grbs2.seek(0)
     #for grb in grbs2:
        #print(grb)
     for key in grbs2.keys():
        print( 'key is %s' % (key,))
        try:
            print( 'value is %s' % (dswrf[key],))
        except:
            pass
    if True:
        grbs2.seek(0);
        if model == "HRRR":
            base = grbs2.select(name='Geopotential Height',
    # Replaced - Hamilton        typeOfLevel='cloudBase',forecastTime=fcst_len_mins)[0]
                                typeOfLevel='unknown',forecastTime=fcst_len_mins)[0]
    # Xue 
        elif model == "HRRR_OPS":
            base = grbs2.select(name='Geopotential Height',
                                typeOfLevel='cloudBase')[0]
    # end of Xue
        elif model == "RAP_130":
             base = grbs2.select(name='Geopotential Height',
                                typeOfLevel='cloudBase')[0]
        else:
            base = None


        grbs2.seek(0);
        if model == "HRRR":
            top = grbs2.select(name='Geopotential Height',
                               typeOfLevel='cloudTop',forecastTime=fcst_len_mins)[0]
        elif model == "HRRR_OPS":
            top = grbs2.select(name='Geopotential Height',
                               typeOfLevel='cloudTop')[0]
        elif model == "RAP_130":
            top = grbs2.select(name='Geopotential Height',
                               typeOfLevel='cloudTop')[0]
        else:
            base = None

        # find parameter numbers at http://ruc.noaa.gov/hrrr/GRIB2Table.txt
        # DSWRF (insolation)
        grbs2.seek(0);
        if model == "HRRR":
# Hamilton  dswrf = grbs2.select(parameterNumber=192,\
            dswrf = grbs2.select(name='Downward short-wave radiation flux',\
                                     parameterCategory=4,discipline=0,forecastTime=fcst_len_mins)[0]
        elif model == "HRRR_OPS":
# Hamilton  dswrf = grbs2.select(parameterNumber=192,\
            dswrf = grbs2.select(name='Downward short-wave radiation flux',\
                                     parameterCategory=4,discipline=0)[0]

        else:
             dswrf = grbs2.select(parameterNumber=192,\
                                     parameterCategory=4,discipline=0)[0]
     # set the grid parameters in w3fb for use by make_stats
    # (maybe this isn't such smart programming!)
    # ASSUME all the other variables loaded are on the same grid
    proj = Projection(dswrf.gridType,
                      dswrf.latitudeOfFirstGridPointInDegrees,
                      dswrf.longitudeOfFirstGridPointInDegrees,
                      dswrf.LoVInDegrees,
                      dswrf.Latin1InDegrees,
                      dswrf.DxInMetres,
                      dswrf.Nx,
                      dswrf.Ny)
    if base != None:
        BASE = base.values
        TOP = top.values
    else:
        BASE = None
        TOP = None
        
    MODEL_DSWRF = dswrf.values
    print( '%d min %s,max %s MODEL_DSWRF' % (pid, MODEL_DSWRF.min(),MODEL_DSWRF.max()))
    #print( '%d min %s ,max %s BASE' % (pid,BASE.min(),BASE.max()))
    #print( pid,'min,max TOP', TOP.min(),TOP.max())
    end_time = time.time()
    proc_time = end_time - start_time
    print("%d %d seconds to read grib file." % (pid,proc_time))
    return(good,proj,BASE,TOP,MODEL_DSWRF)
