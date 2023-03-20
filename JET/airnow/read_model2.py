# module read_model2.py
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

def read_model2(model,run_time,fcst_len):
    #print "model is ",model
    pid = os.getpid()
    start_time = time.time()
    MODEL_filename = get_model_file(model,run_time,fcst_len)
    proj = None
    MODEL_pm2p5= None
    good=False

    if MODEL_filename is None:
        print "file is missing"
        return(good,proj,MODEL_pm2p5,None,None)
    # now process the file
    good = True
    print('model filename is '+MODEL_filename)
    grbs2 = pygrib.open(MODEL_filename)
    # below shows how to get a list of all key/value pairs.
    if False:
     grbs2.seek(0)
     for grb in grbs2:
        if False:
            for key in sorted(grb.keys()):
                print( 'key: %s' % (key,),)
                try:
                    print( ' value: |%s|' % (grb[key],))
                except:
                    pass
        try:
            print(grb)
        except:
            pass
        
    if True:
        pm2p5 = None
 
        grbs2.seek(0);
        if model == "HRRR_GSD" or model == "HRRR_WFIP2":
            pm2p5 = grbs2.select(parameterName='Mass density',forecastTime=fcst_len)[0]
            print 'pm2p5 ',
            print(pm2p5)
            MODEL_pm2p5 = pm2p5.values
            lats,lons = pm2p5.latlons()
       
    proj = Projection(pm2p5.gridType,
                      pm2p5.latitudeOfFirstGridPointInDegrees,
                      pm2p5.longitudeOfFirstGridPointInDegrees,
                      pm2p5.LoVInDegrees,
                      pm2p5.Latin1InDegrees,
                      pm2p5.DxInMetres,
                      pm2p5.Nx,
                      pm2p5.Ny)
    print( '%d min %s,max %s MODEL_pm2p5' % (pid, MODEL_pm2p5.min(),MODEL_pm2p5.max()))
    return(good,proj,MODEL_pm2p5,lats,lons)
