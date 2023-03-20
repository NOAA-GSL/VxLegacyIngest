# module read_hrrr.py
import time 
import pygrib
import os
import sys
from numpy import *
import struct
import time
from Projection import *

def read_hrrr(model,valid_time,fcst_len):
    start_time = time.clock()
    good = True
    if model == "HRRR_GSD":
        filename = time.strftime("/whome/rtrr/hrrr/%Y%m%d%H/postprd/",time.gmtime(valid_time-fcst_len*3600)) + \
                                 """wrftwo_hrconus_%02d.grib2""" % (int(fcst_len))
    else:
        print """no directory known for %s""" % (model)
        sys.exit()
    print "filename", filename
    if not os.path.exists(filename):
        print " is missing\n"
        good=False
        return(good,None,None)
    # now process the file
    grbs2 = pygrib.open(filename)
    for grb in grbs2:
        #print(grb)
        if False:
            for key in sorted(grb.keys()):
                print( 'key is %s' % (key,))
                try:
                    print( 'value is |%s|' % (grb[key],))
                except:
                    pass

    step_range = """%s-%s""" % (fcst_len-1,fcst_len)
    #print "step_range:",step_range
    pcps = grbs2.select(parameterName='Total precipitation', stepRange=step_range)
   # pcps = grbs2.select(stepRange=step_range)
    for grb in pcps:
        print grb
        pcp_1h = grb
        converter = 1
        if pcp_1h['parameterUnits'] == 'kg m-2':
               converter = 3.937  #convert from kg m-2 (= mm) to hundredths of an inch
               #print "converting from kg m -2 to hundredths of an inch"
        else:
            print 'wrong units for 1h accumulations:',pcp_1h['parameterUnits']
            sys.exit()

        # below shows how to get a list of all key/value pairs.
        if False:
         print 'looking for keys in pcp_1h' 
         for key in pcp_1h.keys():
            print( 'key is |%s|' % (key,))
            try:
                print( 'value is |%s|' % (pcp_1h[key],))
            except:
                pass
        break
    PCP_1h1 = pcp_1h.values
    PCP_1h = PCP_1h1*converter
    #print "converter is",converter
    if False:
         for key in PCP_1h.keys():
            print( 'key is %s' % (key,))
            try:
                print( 'value is %s' % (PCP_1h[key],))
            except:
                pass
    
     # set the grid parameters in w3fb for use by make_stats
    # (maybe this isn't such smart programming!)
    # ASSUME all the other variables loaded are on the same grid
    proj = Projection(pcp_1h.gridType,
                      pcp_1h.latitudeOfFirstGridPointInDegrees,
                      pcp_1h.longitudeOfFirstGridPointInDegrees,
                      pcp_1h.LoVInDegrees,
                      pcp_1h.Latin1InDegrees,
                      pcp_1h.DxInMetres,
                      pcp_1h.Nx,
                      pcp_1h.Ny)
    print 'min,max,average pcp_1h in hundredths',pcp_1h['minimum']*converter,pcp_1h['maximum']*converter,\
        pcp_1h['average']*converter
    end_time = time.clock()
    proc_time = end_time - start_time
    #print proc_time,"seconds to read grib file."
    return(proj,good,PCP_1h)
