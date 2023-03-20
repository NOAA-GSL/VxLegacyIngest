#!/usr/bin/env python
#= =====================================================================================
# This script will make links to all necessary files for the web verification page
#
# By: Patrick Hofmann
# Last Update: 13 DEC 2010
#
# To execute: ./retro_web.py
#
#---------------------------------------start-------------------------------------------
import sys
import os
import resource
from datetime import datetime
from datetime import timedelta

def main():
    Year    = os.getenv("YEAR")
    Month   = os.getenv("MONTH")
    Day     = os.getenv("DAY")
    Hour    = os.getenv("HOUR")
    
    src_dir = os.getenv("MAINDIR")
    web_dir = os.getenv("WEBDIR")

    # Static variables
    src_models   = ['HRRR','RR','RUC']
    src_grids    = ['03kmLC','13kmLC','20kmLC','40kmLC','80kmLC']

    models       = ['hrrr','rr','ruc']
    grids        = ['03km','13km','20km','40km','80km']

    trshs        = ['15dBZ','20dBZ','25dBZ','30dBZ','35dBZ','40dBZ','45dBZ']    
    
    #-----------------------------End of Definitions--------------------------------

    # First, set stacksize to 512MB
    resource.setrlimit(resource.RLIMIT_STACK,(1600000000,1600000000))

    init_t = datetime(int(Year),int(Month),int(Day),int(Hour))

    # Construct stage dir date name
    t = datetime(int(Year),int(Month),int(Day),int(Hour))

    while t.day == init_t.day:
        date = t.strftime('%Y%m%d%H')

        # Construct source valid dir name
        valid_dir = '%s-%sz' % (t.strftime('%Y%m%d'),t.strftime('%H'))
        print valid_dir
        
        for [model,src_model] in zip(models,src_models):
            for [grid,src_grid] in zip(grids,src_grids):
                if (grid == '03km' and model != 'hrrr'):
                    continue

                # Make needed web dir
                cmd = 'mkdir -p %s/%s/%s/%s' % (web_dir,model,date,grid)
                #print cmd
                os.system(cmd)

                os.chdir('%s/%s/%s/%s' % (web_dir,model,date,grid))

                # Link src obs file to web dir
                if (os.path.isfile('%s/NSSL/realtime/%s/nssl_mosaic_%s.png' % (src_dir,valid_dir,src_grid))):
                    cmd = 'ln -sf %s/NSSL/realtime/%s/nssl_mosaic_%s.png cref_obs.png' % (src_dir,valid_dir,src_grid)
                    #print cmd
                    os.system(cmd)

                for j in range(0,16):
                    dt = timedelta(hours=-j)
                    ff_t = t + dt
                    print ff_t.strftime('%Y%m%d%H'), j
                    # Link src full model files to web dir
                    if (os.path.isfile('%s/%s/realtime/%s/%s/%s_%sz+%02d_%s.png' % \
                                       (src_dir,src_model,valid_dir,src_grid,model,ff_t.strftime('%Y%m%d%H'),j,src_grid))):
                        cmd = 'ln -sf %s/%s/realtime/%s/%s/%s_%sz+%02d_%s.png cref_f%02d.png' % \
                              (src_dir,src_model,valid_dir,src_grid,model,ff_t.strftime('%Y%m%d%H'),j,src_grid,j)
                        #print cmd
                        os.system(cmd)

                    for trsh in trshs:
                        # Link src score figs to web dir
                        if (os.path.isfile('%s/%s/realtime/%s/%s/nssl_mosaic_vs_%s_%sz+%02d_%sverif_%s.png' % \
                                           (src_dir,src_model,valid_dir,src_grid,model,ff_t.strftime('%Y%m%d%H'),j,trsh,src_grid))):
                            cmd = 'ln -sf %s/%s/realtime/%s/%s/nssl_mosaic_vs_%s_%sz+%02d_%sverif_%s.png cref_%s_f%02d.png' % \
                              (src_dir,src_model,valid_dir,src_grid,model,ff_t.strftime('%Y%m%d%H'),j,trsh,src_grid,trsh,j)
                            #print cmd
                            os.system(cmd)
                       

        delta_t = timedelta(hours=1)
        t = t + delta_t
        

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
