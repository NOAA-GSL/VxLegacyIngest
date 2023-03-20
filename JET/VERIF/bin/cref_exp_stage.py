#!/usr/bin/env python
#= =====================================================================================
# This script will make links to all necessary files for the web verification page
#
# By: Patrick Hofmann
# Last Update: 04 NOV 2010
#
# To execute: ./cref_web_stage.py
#
#---------------------------------------start-------------------------------------------
import sys
import os
import resource

def main():
    Year    = os.getenv("YEAR")
    Month   = os.getenv("MONTH")
    Day     = os.getenv("DAY")
    Hour    = os.getenv("HOUR")
    
    src_dir = os.getenv("MAINDIR")
    web_dir = os.getenv("WEBDIR")

    # Static variables
    src_models   = ['HRRR'] #,'RR','RUC']
    src_grids    = ['03kmLC','13kmLC','20kmLC','40kmLC','80kmLC']

    models       = ['hrrr'] #,'rr','ruc']
    grids        = ['03km','13km','20km','40km','80km']

    trshs        = ['15dBZ','20dBZ','25dBZ','30dBZ','35dBZ','40dBZ','45dBZ']    
    
    #-----------------------------End of Definitions--------------------------------

    # First, set stacksize to 512MB
    resource.setrlimit(resource.RLIMIT_STACK,(1600000000,1600000000))

    # Construct source valid dir name
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,Hour)
    print valid_dir

    # Construct stage dir date name
    date = '%s%s%s%s' % (Year,Month,Day,Hour)

    # Construct model date string
    #date = '%s%s%s%sz' % (Year,Month,Day,Hour)
    
    for [model,src_model] in zip(models,src_models):
        for [grid,src_grid] in zip(grids,src_grids):
            if (grid == '03km' and model != 'hrrr'):
                continue
            
            # Make needed web dir
            cmd = 'mkdir -p %s/hrrr_no6thorder/%s/%s' % (web_dir,date,grid)
            print cmd
            os.system(cmd)

            os.chdir('%s/hrrr_no6thorder/%s/%s' % (web_dir,date,grid))

            # Link src obs file to web dir
            cmd = 'ln -sf %s/NSSL/realtime/%s/nssl_mosaic_%s.png cref_obs.png' % \
                  (src_dir,valid_dir,src_grid)
            print cmd
            os.system(cmd)
            if (not os.path.isfile('cref_obs.png')):
                cmd = 'rm cref_obs.png'
                print cmd
                os.system(cmd)

            for j in range(0,16):
                # Link src full model files to web dir
                cmd = 'ln -sf %s/%s/exps/oper/%s/%s/%s*+%02d*.png cref_f%02d.png' % \
                      (src_dir,src_model,valid_dir,src_grid,model,j,j)
                print cmd
                os.system(cmd)
                if (not os.path.isfile('cref_f%02d.png' % j)):
                    cmd = 'rm cref_f%02d.png' % j
                    print cmd
                    os.system(cmd)

                for trsh in trshs:
                    # Link src score figs to web dir
                    cmd = 'ln -sf %s/%s/exps/oper/%s/%s/nssl_mosaic_vs_*+%02d*_%s*.png cref_%s_f%02d.png' % \
                          (src_dir,src_model,valid_dir,src_grid,j,trsh,trsh,j)
                    print cmd
                    os.system(cmd)
                    if (not os.path.isfile('cref_%s_f%02d.png' % (trsh,j))):
                        cmd = 'rm cref_%s_f%02d.png' % (trsh,j)
                        print cmd
                        os.system(cmd)

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
