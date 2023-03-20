# module read_hrrr.py
import time 
import pygrib
import os
import sys
from numpy import *
import struct
import time
from Projection2 import *

def read_hrrr3(model,run_time,fcst_len):
    start_time = time.clock()
    good = True
    if model == "HRRR_GSD":
        filename = time.strftime("/whome/rtrr/hrrr/%Y%m%d%H/postprd/",\
                                 time.gmtime(run_time)) + \
                                 """wrftwo_hrconus_%02d.grib2""" % (int(fcst_len))
    elif model == "RAP_GSD":
        filename = time.strftime("/whome/rtrr/rr/%Y%m%d%H/postprd/",\
                                     time.gmtime(run_time)) + \
                                     """wrftwo_130_%02d.grib2""" % (int(fcst_len))
    elif model == "HRRR_OPS":
        filename = time.strftime("/public/data/grids/hrrr/conus/wrfsfc/grib2/%y%j%H00",\
                                     time.gmtime(run_time)) + \
                                     """%04d""" % (int(fcst_len))
    elif model == "RAP_OPS":
        filename = time.strftime("/public/data/grids/rap/iso_130/grib2/%y%j%H00",\
                                     time.gmtime(run_time)) + \
                                     """%04d""" % (int(fcst_len))
    elif model == "NBM":
        filename = time.strftime("/public/data/grids/nbm/conus/master/grib2/%y%j%H00",\
                                     time.gmtime(run_time)) + \
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
    step_range = """%s-%s""" % (fcst_len-1,fcst_len)
    print "step_range:",step_range
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
        if grb['parameterName'] != 'Total precipitation':
            continue
        print os.getpid(),
        print(grb)
        if grb['stepRange'] != step_range:
            print("wrong stepRange. skipping")
            continue
        try:
            if grb['probabilityType'] == 1:
                # get rid of probability fields
                print os.getpid(),
                print("A probability field, skipping.")
                continue
        except Exception as e:
            # this key may not be present
            pass
        if grb['parameterUnits'] != 'kg m-2':
            print os.getpid(),
            print("wrong units!")
            continue
        pcp_1h = grb
        break 
    print os.getpid(),
    print "found",
    print(pcp_1h)
    converter = 3.937  #convert from kg m-2 (= mm) to hundredths of an inch
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
    #sys.exit()
    proj = Projection2(name=pcp_1h.gridDefinitionDescription,
                      alat1=pcp_1h.latitudeOfFirstGridPointInDegrees,
                      elon1=pcp_1h.longitudeOfFirstGridPointInDegrees,
                      elonv=pcp_1h.LoVInDegrees,
                      alattan=pcp_1h.Latin1InDegrees,
                      dx=pcp_1h.DxInMetres,
                      nx=pcp_1h.Nx,
                      ny=pcp_1h.Ny)
    print os.getpid(),
    print "projection is",proj
    print os.getpid(),
    print 'min,max,average pcp_1h in hundredths',pcp_1h['minimum']*converter,pcp_1h['maximum']*converter,\
        pcp_1h['average']*converter
    end_time = time.clock()
    proc_time = end_time - start_time
    #print proc_time,"seconds to read grib file."
    return(proj,good,PCP_1h)
