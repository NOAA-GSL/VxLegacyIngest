#!/usr/bin/env python
#= =====================================================================================
# This script will copy softlinks on Jet to our local GSD storage on ratchet:/data/amb/verif
#
# By: Patrick Hofmann
# Last Update: 15 NOV 2011
#
# To execute: ./cp_verif_to_gsd.py
#
#---------------------------------------start-------------------------------------------
import sys
import os
import resource
import tarfile
import glob
from datetime import datetime

def main():
    Year    = '2011'
    Month   = '11'
    Day     = '22'
    Hour    = '10'
    
    web_dir = '/pan1/projects/nrtrr/verif/web'
    var     = 'cref'

    # Static variables 
    models       = ['hrrr','hrrr_dev','rr','rr_dev','rr_dev2','ruc','ruc_dev','nam','nam_nest']
    grids        = ['03km','13km','20km','40km','80km']
    
    #-----------------------------End of Definitions--------------------------------

    # First, set stacksize to 512MB
    resource.setrlimit(resource.RLIMIT_STACK,(1600000000,1600000000))

    # Use built-in Date/Time modules
    t = datetime(int(Year),int(Month),int(Day),int(Hour))

    # Construct stage dir date name
    date = '%4d%02d%02d%02d' % (t.year,t.month,t.day,t.hour)
    
    for model in models:
       
        # Go to web dir
        try:
            os.chdir('%s/%s/%s' % (web_dir,model,date))
        except os.OSError, oerr:
            print model, ' is missing'
            continue
        
        # Make tar file
        try:
            # Open tar file
            tf = tarfile.open('%s.tgz' % date,'w:gz')

            # dereference symbolic links
            tf.dereference = True

            # add all directories to tarball
            for grid in grids:
                for file in glob.glob('%s/%s*' % (grid,var)):
                    print 'adding %s' % file
                    tf.add(file)
            tf.close()

            # Copy file to GSD
            cmd = 'scp %s.tgz rtrr@ratchet:/data/amb/verif/web' % date
            print cmd
            os.system(cmd)

            # Untar remote file
            cmd = "ssh rtrr@ratchet '(cd /data/amb/verif/web;tar -xvpf %s.tgz)'" % date
            print cmd
            os.system(cmd)
            
            # Remove src links
            cmd = 'rm -rf *'
            print cmd
            #os.system(cmd)

        except tarfile.TarError, err:
            print 'ERROR: could not open tarfile'
            

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
