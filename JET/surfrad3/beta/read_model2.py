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
    MODEL_filename = get_model_file(model,run_time,fcst_len_mins)
    avg15 = "%s-%s" % (fcst_len_mins - 15,fcst_len_mins);
    fcst_len_mins_start = fcst_len_mins - 15
    proj = None
    MODEL_DIRECT = None
    MODEL_DIFFUSE = None
    MODEL_DSWRF = None
    MODEL_DSWRF15 = None
    MODEL_DIRECT15 = None
    MODEL_DIFFUSE15 = None   # doesn't seem to exist at the moment (Aug 2017)
    BASE = None
    TOP = None
    good=False

    if MODEL_filename is None:
        print "file is missing"
        return(good,proj,BASE,TOP,MODEL_DSWRF,MODEL_DIRECT,MODEL_DIFFUSE,\
                   MODEL_DSWRF15,MODEL_DIRECT15,MODEL_DIFFUSE15)
    # now process the file
    good = True
    print('model filename is '+MODEL_filename)
    grbs2 = pygrib.open(MODEL_filename)
    for grb in grbs2:
        lats,lons = grb.latlons()
        #print 'shape',lats.shape
        #print 'lats',lats[0:3,0:3]
        #print 'lons',lons[0:3,0:3]
        break
    # below shows how to get a list of all key/value pairs.
    if False:
     grbs2.seek(0)
     for grb in grbs2:
        print(grb)
        if False:
            for key in sorted(grb.keys()):
                print( 'key is %s' % (key,))
                try:
                    print( 'value is |%s|' % (grb[key],))
                except:
                    pass
    if True:
        base = None

        # find parameter numbers at https://ruc.noaa.gov/hrrr/GRIB2Table.txt
        # DSWRF (insolation)
        grbs2.seek(0);
        #for grb in grbs2:
		#print grb
        if model == "HRRR" or model == "HRRR_WFIP2":
            dswrf = grbs2.select(parameterName='Downward short-wave radiation flux',forecastTime=fcst_len_mins)[0]
            print 'DSWRF ',
            print(dswrf)
            direct = grbs2.select(parameterNumber=200,\
                                     parameterCategory=4,discipline=0,forecastTime=fcst_len_mins)[0]
            print 'DIRECT ',
            print(direct)
            diffuse = grbs2.select(parameterNumber=201,\
                                     parameterCategory=4,discipline=0,forecastTime=fcst_len_mins)[0]
            print 'DIFFUSE ',
            print(diffuse)
            if fcst_len_mins >= 15:
                #dswrf15 = grbs2.select(parameterName='Downward short-wave radiation flux',stepRange=avg15)[0] # Old way using old pygrib - JAH 20190408
                dswrf15 = grbs2.select(parameterName='Downward short-wave radiation flux',forecastTime=fcst_len_mins_start,endStep=fcst_len_mins)[0]
                print 'DSWRF15',
                print(dswrf15)
                MODEL_DSWRF15 = dswrf15.values
                #direct15 = grbs2.select(parameterNumber=200,parameterCategory=4,discipline=0,stepRange=avg15)[0] # Old way using old pygrib - JAH 20190408
                direct15 = grbs2.select(parameterNumber=200,parameterCategory=4,discipline=0,forecastTime=fcst_len_mins_start,endStep=fcst_len_mins)[0]
                print 'DIRECT15',
                print(direct15)
                MODEL_DIRECT15 = direct15.values
                if False:
                        for key in sorted(direct15.keys()):
                            sys.stdout.write( 'key is %s... ' % (key))
                            try:
                                print( 'value is |%s|' % (direct15[key],))
                            except:
                                print('ignoring error')
                                pass
                 #diffuse = grbs2.select(parameterNumber=201,parameterCategory=4,discipline=0,stepRange=avg15)[0]
                #print(diffuse)
                #MODEL_DIFFUSE15 = diffuse15.values
            MODEL_DIRECT = direct.values
            MODEL_DIFFUSE = diffuse.values
            MODEL_DSWRF = dswrf.values
        elif model == "HRRR_NREL" or model == "HRRR_OPS":
            dswrf = grbs2.select(parameterName='Downward short-wave radiation flux')[0]
            direct = grbs2.select(parameterNumber=200,\
                                     parameterCategory=4,discipline=0)[0]
            diffuse = grbs2.select(parameterNumber=201,\
                                     parameterCategory=4,discipline=0)[0]
            MODEL_DIRECT = direct.values
            MODEL_DIFFUSE = diffuse.values
            MODEL_DSWRF = dswrf.values
        elif model.startswith("RAP"):
           dswrf = grbs2.select(parameterName='Downward short-wave radiation flux')[0]
           MODEL_DSWRF = dswrf.values
        elif model == "NAM":
           #dswrf = grbs2.select(parameterName='Downward short-wave radiation flux')[0]
           dswrf = grbs2[787]
           print(dswrf)
           MODEL_DSWRF = dswrf.values
        else:
            # assume HRRR retro
            dswrf = grbs2.select(parameterName='Downward short-wave radiation flux')[0]
            print 'DSWRF ',
            print(dswrf)
            MODEL_DSWRF = dswrf.values
    if base != None:
        BASE = base.values
        TOP = top.values
        
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
    print( '%d min %s,max %s MODEL_DSWRF' % (pid, MODEL_DSWRF.min(),MODEL_DSWRF.max()))
    if type(MODEL_DSWRF15) != type(None):
        print( '%d min %s,max %s MODEL_DSWRF15' % (pid, MODEL_DSWRF15.min(),MODEL_DSWRF15.max()))
    if type(MODEL_DIRECT) != type(None):
        print( '%d min %s,max %s MODEL_DIRECT' % (pid, MODEL_DIRECT.min(),MODEL_DIRECT.max()))
        if type(MODEL_DIRECT15) != type(None):
            print( '%d min %s,max %s MODEL_DIRECT15' % (pid, MODEL_DIRECT15.min(),MODEL_DIRECT15.max()))
        print( '%d min %s,max %s MODEL_DIFFUSE' % (pid, MODEL_DIFFUSE.min(),MODEL_DIFFUSE.max()))
        #print( '%d min %s,max %s MODEL_DIFFUSE15' % (pid, MODEL_DIFFUSE15.min(),MODEL_DIFFUSE15.max()))
    end_time = time.time()
    proc_time = end_time - start_time
    print("%d %d seconds to read grib file." % (pid,proc_time))
    print("good date = %s" % good)
    return(good,proj,BASE,TOP,MODEL_DSWRF,MODEL_DIRECT,MODEL_DIFFUSE,\
               MODEL_DSWRF15,MODEL_DIRECT15,MODEL_DIFFUSE15)
