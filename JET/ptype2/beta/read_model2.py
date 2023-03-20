# module read_model.py
import time 
import pygrib
#from netCDF4 import Dataset
import os
import sys
from numpy import *
import numpy.ma as ma
import struct
import time
from get_model_file import *
from Projection import *

def read_model2(model,run_time,fcst_len_mins):
    pid = os.getpid()
    start_time = time.time()
    good = True
    MODEL_filename = get_model_file(model,run_time,fcst_len_mins)
    #print "filename is:",MODEL_filename
    if MODEL_filename is None:
        good=False
        return(good,None,None,None,None,None)
    # now process the file
    grbs2 = pygrib.open(MODEL_filename)
    #print 'here1'
    if False:
     for grb in grbs2:
        try:
            print(grb)
        except:
            pass
    if False:
      grbs2.seek(0)
      try: 
       crain = grbs2.select(name='Categorical snow')[0]
       print 'printing crain'
       print(crain)
      except:
          pass
      if False:
        for key in crain.keys():
         print( 'key is %s' % (key,))
         try:
            print( 'value is %s' % (crain[key],))
         except:
            pass

    if True:
        grbs2.seek(0);
        if "HRRR" in model:
            crain = grbs2.select(parameterNumber=192,\
                                     parameterCategory=1,discipline=0,forecastTime=fcst_len_mins)[0]
            grbs2.seek(0)
            cfrzr = grbs2.select(parameterNumber=193,\
                                 parameterCategory=1,discipline=0,forecastTime=fcst_len_mins)[0]
            grbs2.seek(0)
            cicep = grbs2.select(parameterNumber=194,\
                                 parameterCategory=1,discipline=0,forecastTime=fcst_len_mins)[0]
            grbs2.seek(0)
            csnow = grbs2.select(name='Categorical snow',\
                                     parameterCategory=1,discipline=0,forecastTime=fcst_len_mins)[0]
        elif model == 'NAMnest_OPS_227':
            #print """getting %s ptypes""" % (model)
            crain = grbs2.select(name='Categorical rain')[0]
            grbs2.seek(0)
            cfrzr = grbs2.select(name='Categorical freezing rain')[0]
            grbs2.seek(0)
            cicep = grbs2.select(name='Categorical ice pellets')[0]
            grbs2.seek(0)
            csnow = grbs2.select(name='Categorical snow')[0]
        else:
            crain = grbs2.select(parameterNumber=192,\
                                     parameterCategory=1,discipline=0)[0]
            grbs2.seek(0)
            cfrzr = grbs2.select(parameterNumber=193,\
                                     parameterCategory=1,discipline=0)[0]
            grbs2.seek(0);
            cicep = grbs2.select(parameterNumber=194,\
                                     parameterCategory=1,discipline=0)[0]
            grbs2.seek(0);
            csnow = grbs2.select(parameterNumber=195,\
                                     parameterCategory=1,discipline=0)[0]
    # set the grid parameters in w3fb for use by make_stats
    # (maybe this isn't such smart programming!)
    # ASSUME all the other variables loaded are on the same grid
    proj = Projection(crain.gridType,
                      crain.latitudeOfFirstGridPointInDegrees,
                      crain.longitudeOfFirstGridPointInDegrees,
                      crain.LoVInDegrees,
                      crain.Latin1InDegrees,
                      crain.DxInMetres,
                      crain.Nx,
                      crain.Ny)
    #print 'projection is',proj
    # get rid of masks, if any (NAMnest is masked)
    # seems to work for NAMnest rain, but not for the other values... check this.
    CRAIN = ma.filled(crain.values,0)
    CFRZR = ma.filled(cfrzr.values,0)
    CICEP = ma.filled(cicep.values,0)
    CSNOW = ma.filled(csnow.values,0)
    end_time = time.time()
    proc_time = end_time - start_time
    print("%d %d seconds to read grib file %s" % (pid,proc_time,MODEL_filename))
    return(good,proj,CRAIN,CFRZR,CICEP,CSNOW)
