# module read_gfs.py
import time 
import pygrib
import os
import sys
from numpy import *
import struct
import time
from Projection2 import *

def read_gfs(model,valid_time,fcst_len):
    start_time = time.clock()
    good = True
    if model == "GFS_OPS":
        filename = time.strftime("/public/data/grids/gfs/0p25deg/grib2/%y%j%H00",\
                                     time.gmtime(valid_time-fcst_len*3600)) + \
                                     """%04d""" % (int(fcst_len))
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

    step_range = """%s-%s""" % (fcst_len-3,fcst_len)
    #print "step_range:",step_range
    pcps = grbs2.select(parameterName='Total precipitation',stepRange=step_range)
    for grb in pcps:
        print "NEW GRIB RECORD"
        print grb
        pcp_3h = grb
        converter = 1
        if pcp_3h['parameterUnits'] == 'kg m-2':
               converter = 3.937  #convert from kg m-2 (= mm) to hundredths of an inch
               #print "converting from kg m -2 to hundredths of an inch"
        else:
            print 'wrong units for 3h accumulations:',pcp_3h['parameterUnits']
            sys.exit()

        # below shows how to get a list of all key/value pairs.
        if False:
         print 'looking for keys in pcp_3h' 
         for key in pcp_3h.keys():
            print( 'key is |%s|' % (key,))
            try:
                print( 'value is |%s|' % (pcp_3h[key],))
            except:
                pass
        #break
    pcp_3h1 = pcp_3h.values
    pcp_3h_vals = pcp_3h1*converter
    #print "converter is",converter
    if False:
         for key in pcp_3h.keys():
            print( 'key is %s' % (key,))
            try:
                print( 'value is %s' % (pcp_3h[key],))
            except:
                pass
    
    # set the grid parameters in w3fb for use by make_stats
    # (maybe this isn't such smart programming!)
    # ASSUME all the other variables loaded are on the same grid
    #sys.exit()
    proj = Projection2(name=pcp_3h.gridDefinitionDescription,
                      first_lat=pcp_3h.latitudeOfFirstGridPointInDegrees,
                      first_lon=pcp_3h.longitudeOfFirstGridPointInDegrees,
                      dx=pcp_3h.iDirectionIncrementInDegrees,
                      dy=pcp_3h.jDirectionIncrementInDegrees,
                      nx=pcp_3h.Ni,
                      ny=pcp_3h.Nj)
    print "projection is",proj
    print 'min,max,average pcp_3h in hundredths',pcp_3h['minimum']*converter,pcp_3h['maximum']*converter,\
        pcp_3h['average']*converter
    end_time = time.clock()
    proc_time = end_time - start_time
    #print proc_time,"seconds to read grib file."
    return(proj,good,pcp_3h_vals)
