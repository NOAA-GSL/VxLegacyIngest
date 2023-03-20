#!/usr/bin/env python
###################
#
# Name: ens_verif_netcdf.py
#
# Description: script for reading Trevor's ensemble verificaiton netcdf files
#
# His XML files are located here: /home/wrfruc/HRRRE_verif/xml/
# His verification scripts are located in this directory: /home/wrfruc/HRRRE/bin/UPP
# His verification netcdf files are located in this directory: /lfs1/projects/wrfruc/HRRRE/verif
#
# History:
#   INITIAL VERSION - Jeff Hamilton GSD/ADB, 20200203
#
###################
import sys
import os, time, math
from netCDF4 import Dataset

def main(netcdf_file):

    print 'Verif file: ',netcdf_file.split('/')[-1]
    nc = Dataset(netcdf_file,'r')
    fcst_leads = nc.variables['fhour'][:]
    thresholds = nc.variables['threshold'][:]
    kernel = nc.variables['smooth'][:]
    radius = nc.variables['radius'][:]
    prob_bin = nc.variables['prob'][:]
    fcstcount = nc.variables['fcstcount'][:,:,:,:] # (f,t,s,p)
    hitcount = nc.variables['hitcount'][:,:,:,:] # (f,t,s,p)
    nhdfcstcount = nc.variables['nhdfcstcount'][:,:,:,:] # (f,t,s,p)
    nhdhitcount = nc.variables['nhdhitcount'][:,:,:,:] # (f,t,s,p)
    fss = nc.variables['fss'][:,:,:] # (f,t,r)
    nc.close()

    #for fcst_len in fcst_leads:
    for i in range(0,len(fcst_leads)):
       #print('fcst_len: %s' % (str(fcst_leads[i])))
       for j in range(0,len(thresholds)):
          for k in range(0,len(radius)):
             print('###############################')
             print('fcst_len: %s' % (str(fcst_leads[i])))
             print('threshold: %s' % (str(thresholds[j])))
             print('radius: %s' % (str(radius[k])))
             print('FSS: %s' % (str(fss[i,j,k])))

####### main ##########

if __name__ == "__main__":
    netcdf_file = sys.argv[1]
    main(netcdf_file)
