from netCDF4 import Dataset
import os
import sys
from numpy import *
import struct
import time
from time import strptime
from datetime import datetime
from Projection2 import *

def print_ncattr(nc_fid,key):
    try:
            print "\t\ttype:", repr(nc_fid.variables[key].dtype)
            for ncattr in nc_fid.variables[key].ncattrs():
                print '\t\t%s:' % ncattr,\
                      repr(nc_fid.variables[key].getncattr(ncattr))
    except KeyError:
            print "\t\tWARNING: %s does not contain variable attributes" % key   


def read_stage4(model,valid_time,fcst_len):
    start_time = time.clock()
    good = True
    if model == "STAGE4_6h":
        filename = time.strftime("/lfs3/projects/rtwbl/ejames/stage4/%Y%m/stageIV_%Y%m%d%H.nc",
                                 time.gmtime(valid_time-fcst_len*3600))
    else:
        print """no directory known for %s""" % (model)
        sys.exit()
    print "filename", filename
    if not os.path.exists(filename):
        print " is missing\n"
        good=False
        return(good,None,None)
    # now process the file
    nc_fid = Dataset(filename,'r')
    # NetCDF global attributes
    nc_attrs = nc_fid.ncattrs()
    verb = False
    if verb:
        print "NetCDF Global Attributes:"
        for nc_attr in nc_attrs:
            print '\t%s:' % nc_attr, repr(nc_fid.getncattr(nc_attr))
    nc_dims = [dim for dim in nc_fid.dimensions]  # list of nc dimensions
    # Dimension shape information.
    if verb:
        print "NetCDF dimension information:"
        for dim in nc_dims:
            print "\tName:", dim 
            print "\t\tsize:", len(nc_fid.dimensions[dim])
            print_ncattr(nc_fid,dim)
    # Variable information.
    nc_vars = [var for var in nc_fid.variables]  # list of nc variables
    if verb:
        print "NetCDF variable information:"
        for var in nc_vars:
            if var not in nc_dims:
                print '\tName:', var
                print "\t\tdimensions:", nc_fid.variables[var].dimensions
                print "\t\tsize:", nc_fid.variables[var].size
                print_ncattr(nc_fid,var)
    dt = str(nc_fid.getncattr('ValidTime'))[0:]
    print 'dt',dt
    dt_obj = datetime(*(time.strptime(dt, "%Y%m%d%H")[0:6]))
    runtime_from_file = int((dt_obj-datetime(1970,1,1)).total_seconds())
    valid_time_from_file = runtime_from_file + 3600*fcst_len
    vtf_str = datetime.utcfromtimestamp(valid_time_from_file)
    vt_str = datetime.utcfromtimestamp(valid_time)
    if valid_time_from_file != valid_time:
        print("VALID TIME FROM FILE %s (%s)\n\tDOES NOT AGREE WITH DESIRED VALID TIME (%s) ... skipping"% \
              (filename,vtf_str,vt_str))
        sys.exit()
        good=False
        return(good,None,None)

    print("VALID TIME FROM FILE AGREES WITH DESIRED VALID TIME (%s)"% (vtf_str))
    pcp_6h = nc_fid.variables['precip'][:]*100 # convert to hundredths of an inch
   
    # set the grid parameters in w3fb for use by make_stats
    # (maybe this isn't such smart programming!)
    # ASSUME all the other variables loaded are on the same grid
    #sys.exit()
    proj = Projection2(name=nc_fid.getncattr("MapProjection"),
                       alat1=float(nc_fid.getncattr("SW_corner_lat")),
                      elon1=float(nc_fid.getncattr("SW_corner_lon")),
                      elonv=float(nc_fid.getncattr("Standard_lon")),
                      alattan=float(nc_fid.getncattr("Standard_lat")),
                      dx=float(nc_fid.getncattr("XGridSpacing")),
                      nx=len(nc_fid.dimensions['x']),
                      ny=len(nc_fid.dimensions['y']))
    print "projection is",proj
    end_time = time.clock()
    proc_time = end_time - start_time
    #print proc_time,"seconds to read grib file."
    return(proj,good,pcp_6h)
