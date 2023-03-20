#!/usr/bin/env python
#= =====================================================================================
# This script will copy softlinks on Jet to our local GSD storage on ratchet:/data/amb/verif
#
# By: Patrick Hofmann
# Last Update: 15 MAR 2012
#
# To execute: ./cp_verif_to_gsd.py
#
#---------------------------------------start-------------------------------------------
import sys
import os
import resource
import tarfile
import glob
import os.path
from datetime import datetime

def main():
    Year    = os.getenv("YEAR")
    Month   = os.getenv("MONTH")
    Day     = os.getenv("DAY")
    Hour    = os.getenv("HOUR")
    
    src_dir = os.getenv("MAINDIR")
    web_dir = os.getenv("WEBDIR")
    var     = os.getenv("VAR")

    # Static variables 
    models       = (os.getenv("WEBMODELS")).split()
    grids        = (os.getenv("WEBGRIDS")).split()
    
    #-----------------------------End of Definitions--------------------------------

    # First, set stacksize to 512MB
    #resource.setrlimit(resource.RLIMIT_STACK,(800000000,800000000))

    # Use built-in Date/Time modules
    t = datetime(int(Year),int(Month),int(Day),int(Hour))

    # Construct stage dir date name
    date = '%4d%02d%02d%02d' % (t.year,t.month,t.day,t.hour)
    
    for model in models:
       
        # Go to web dir
        try:
            os.chdir('%s' % (web_dir))
        except os.OSError, oerr:
            print web_dir, ' is missing'
            continue
        
        # Make tar file
        try:
            # Open tar file
            tname = '%s_%s.tgz' % (model,date)
            tf = tarfile.open(tname,'w:gz')

            # dereference symbolic links
            tf.dereference = True

            # add all directories to tarball
            for grid in grids:
                for file in glob.glob('%s/%s/%s/%s*' % (model,date,grid,var)):
                    if (os.path.isfile(file)):
                        print 'adding %s' % file
                        tf.add(file)
            tf.close()

            # Check for nonzero file
            if (os.path.getsize(tname) == 0):
                # Remove src links and tarball
                for grid in grids:
                    cmd = 'rm -rf %s/%s/%s/%s* %s' % (model,date,grid,var,tname)
                    if (var == 'precip'):
                        cmd += ' %s/%s' % (model,date)
                    print cmd
                    os.system(cmd)
                continue
            
            # Copy file to GSD
            cmd = 'scp %s amb-verif@ratchet.fsl.noaa.gov:/data/amb/verif/web' % tname
            print cmd
            os.system(cmd)

            # Untar remote file
            cmd = "ssh amb-verif@ratchet.fsl.noaa.gov '(cd /data/amb/verif/web;tar -xvpf %s; rm %s)'" % (tname,tname)
            print cmd
            os.system(cmd)
            
            # Remove src links and tarball
            for grid in grids:
                cmd = 'rm -rf %s/%s/%s/%s* %s' % (model,date,grid,var,tname)
                if (var == 'precip'):
                    cmd += ' %s/%s' % (model,date)
                print cmd
                os.system(cmd)

        except tarfile.TarError, err:
            print 'ERROR: could not open tarfile'
            

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
