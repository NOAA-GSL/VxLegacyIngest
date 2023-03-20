#!/usr/bin/env python
#= =====================================================================================
# This script will make links to all necessary files for the web verification page
#
# By: Patrick Hofmann
# Last Update: 09 DEC 2011
#
# To execute: ./precip_web_stage.py
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

    src_models   = (os.getenv("SRCMODELS")).split()
    src_grids    = (os.getenv("SRCGRIDS")).split()

    models       = (os.getenv("DIRMODELS")).split()
    web_models   = (os.getenv("WEBMODELS")).split()
    grids        = (os.getenv("WEBGRIDS")).split()

    trshs        = ['0.01in','0.10in','0.25in','0.50in','1.00in','1.50in','2.00in','3.00in']
    
    #-----------------------------End of Definitions--------------------------------

    # First, set stacksize to 512MB
    resource.setrlimit(resource.RLIMIT_STACK,(800000000,800000000))

    # Construct source valid dir name
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,Hour)
    print valid_dir

    # Construct stage dir date name
    date = '%s%s%s%s' % (Year,Month,Day,Hour)

    # Construct model date string
    #date = '%s%s%s%sz' % (Year,Month,Day,Hour)
    
    for [model,web_model,src_model] in zip(models,web_models,src_models):
        for [grid,src_grid] in zip(grids,src_grids):

            # Make needed web dir
            cmd = 'mkdir -p %s/%s/%s/%s' % (web_dir,web_model,date,grid)
            print cmd
            os.system(cmd)

            os.chdir('%s/%s/%s/%s' % (web_dir,web_model,date,grid))

            # Link src obs file to web dir
            cmd = 'ln -sf %s/StageIV/realtime/%s/stageIV_6hr_precip_%s.png precip_obs.png' % \
                  (src_dir,valid_dir,src_grid)
            print cmd
            os.system(cmd)
            if (not os.path.isfile('precip_obs.png')):
                cmd = 'rm precip_obs.png'
                print cmd
                os.system(cmd)

            for j in ['2fcst','8fcst','24fcst']:
                # Link src full model files to web dir
                cmd = 'ln -sf %s/%s/realtime/%s/%s/%s_%s_24hr_total*.png precip_%s_model.png' % \
                      (src_dir,src_model,valid_dir,src_grid,model,j,j)
                print cmd
                os.system(cmd)
                if (not os.path.isfile('precip_%s_model.png' % j)):
                    cmd = 'rm precip_%s_model.png' % j
                    print cmd
                    os.system(cmd)

                for trsh in trshs:
                    # Link src score figs to web dir
                    cmd = 'ln -sf %s/%s/realtime/%s/%s/stageIV_6hr_precip_vs*%s*%s*.png precip_%s_%s.png' % \
                          (src_dir,src_model,valid_dir,src_grid,j,trsh,trsh,j)
                    print cmd
                    os.system(cmd)
                    if (not os.path.isfile('precip_%s_%s.png' % (trsh,j))):
                        cmd = 'rm precip_%s_%s.png' % (trsh,j)
                        print cmd
                        os.system(cmd)
                        
#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
