# module read_model.py
import time 
import pygrib
from netCDF4 import Dataset
import os
import sys
from numpy import *
import struct
from datetime import *
import calendar as cal
import time
from get_model_file import *
from Projection import *
from string import *

def read_netcdf(model,run_time,fcst_len_mins):
    print "into read_netcdf"
    pid = os.getpid()
    start_time = time.time()
    good = True
    MODEL_filename = get_model_file(model,run_time,fcst_len_mins)
    if MODEL_filename != None:
        print('model filename is '+MODEL_filename)
    if MODEL_filename is None:
        good=False
        return(good,None,None,None,None)
    # now process the file
    f = Dataset(MODEL_filename,"r")
    #for name in f.ncattrs():
        #print 'global attr',name, '=', getattr(f,name)
    times = f.variables['Times'][:][:]
    i=0
    for time1 in times:
        t1=""
        for element in time1:
            t1 +=element
        new_time = datetime.strptime(t1,"%Y-%m-%d_%H:%M:%S")
        valid_secs = cal.timegm(datetime.timetuple(new_time))
        this_fcst_len_mins = (valid_secs - run_time)/60
        if this_fcst_len_mins == fcst_len_mins:
            i_fcst = i
            break
        i += 1
    print "i_fcst is",i_fcst,', this_fcst_len_mins',this_fcst_len_mins
    swddir = f.variables['SWDDIR'][i_fcst,:,:]
    swddif = f.variables['SWDDIF'][i_fcst,:,:]
    # apparently, the 'SWDOWN' is already the sum of direct and diffuse,
    # but we'll do it this way just for the heck of it.
    dswrf = swddir + swddif
    xlat0 = f.variables['XLAT'][i_fcst,0,0]
    xlon0 = f.variables['XLONG'][i_fcst,0,0]
    base = None
    top = None
    #print 'swddir',swddir
    #print 'swddif',swddif
    #print 'dswrf',dswrf.shape,dswrf
     # set the grid parameters in w3fb for use by make_stats
    # (maybe this isn't such smart programming!)
    # ASSUME all the other variables loaded are on the same grid
    proj = Projection(getattr(f,'MAP_PROJ_CHAR'),
                      xlat0,xlon0,                                     # lower left corner 
                      getattr(f,'CEN_LON'),
                      getattr(f,'TRUELAT1'),
                      getattr(f,'DX'),
                      dswrf.shape[1],
                      dswrf.shape[0])
    #print 'projection',proj
    MODEL_DSWRF = dswrf
    print( '%d min %s,max %s MODEL_DSWRF' % (pid, MODEL_DSWRF.min(),MODEL_DSWRF.max()))
    #print( '%d min %s ,max %s BASE' % (pid,BASE.min(),BASE.max()))
    #print( pid,'min,max TOP', TOP.min(),TOP.max())
    end_time = time.time()
    proc_time = end_time - start_time
    print("%d %d seconds to read grib file." % (pid,proc_time))
    return(good,proj,base,top,dswrf)
