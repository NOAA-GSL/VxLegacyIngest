#!/usr/bin/env python
#======================================================================================
# This script will retrieve and stitch together the 8 NSSL tiles into 1 mosaic file,
# and then interpolate the 1km grid into all the necessary scales, along with plot
# each field.
#
# By: Patrick Hofmann
# Last Update: 04 OCT 2010
#
# To execute: ./NSSL_retro.py
#
# Example NSSL file: 20100428-120000.netcdf.gz
# Recent (1-2 days) dir: /public/data/radar/nssl/mosaic2d_nc/tileX/YYYYMMDD-HH0000.netcdf.gz
# Archive dir: /arch2/fdr/YYYY/MM/DD/data/radar/nssl/mosaic2d_nc/tileX/YYYYMMDDHH00.tar.gz
# * files in clumps of 6 hours starting at 00
#
#---------------------------------------start-------------------------------------------
import sys
import os
import resource
from datetime import datetime
from datetime import timedelta

def main():
    Year       = os.getenv("YEAR")
    Month      = os.getenv("MONTH")
    Day        = os.getenv("DAY")
    #valid_time = os.getenv("HOUR")
    valid_times = ['%02d' % x for x in range(0,24)]
    
    exec_dir   = os.getenv("EXECDIR")
    script_dir = os.getenv("SCRIPTDIR")
    nssl_dir   = os.getenv("REALTIMEDIR")
    obs_dir    = os.getenv("OBSDIR")
    
    hrrr_mask  = os.getenv("HRRRMASK")
    nssl_mask  = os.getenv("NSSLMASK")
    
    # Interpolation options
    opts = os.getenv("IPOPTS")
    orig_interp_opts = opts.split()

    # Static variables
    orig_obs_grid     = '01kmCE'
    interp_grids      = ['03kmLC','13kmLC','10kmLC','20kmLC','40kmLC','80kmLC'] 

    interp_method = 'neighbor-budget'
    interp_func   = 'average'
    
    mosaic_file = 'nssl_mosaic'
    obs_nc_var = 'cref'

    orig_nml_file = 'input.nml'
    
    #-----------------------------End of Definitions--------------------------------

    # First, set stacksize to 512MB
    resource.setrlimit(resource.RLIMIT_STACK,(1600000000,1600000000))

    for valid_time in valid_times:
        # Construct valid dir under run dir
        valid_dir = '%s%s%s-%sz' % (Year,Month,Day,valid_time)
        print valid_dir
        os.chdir(nssl_dir)
        os.chdir(valid_dir)
        
        if (os.path.isfile('%s.nc' % mosaic_file)):
            
            cmd = 'ln -sf nssl_mosaic.nc nssl_mosaic_01kmCE.nc'
            print cmd
            os.system(cmd)

            obs_grid    = orig_obs_grid
            interp_opts = orig_interp_opts
            
            for (interp_grid,i) in zip(interp_grids,range(0,6)):
                
                if (interp_grid == '03kmLC' or interp_grid == '13kmLC'):
                    hgt_mask = nssl_mask
                else:
                    hgt_mask = hrrr_mask

                if (i >= 2):
                    obs_grid = '03kmLC'
                
                if (i == 1):
                    interp_opts[0] = 8
                else:
                    interp_opts[0] = 2 ** (i-1)
                    interp_opts[0] = max(interp_opts[0],2)

                obs_in_file  = '%s_%s' % (mosaic_file,obs_grid)
                ncl_obs_file = '%s_%s' % (mosaic_file,interp_grid)
                nml_file     = '%s_%s' % (interp_grid,orig_nml_file)

                print obs_grid, interp_grid
                print interp_opts
                
                # Write namelist
                nml = open(nml_file,'w')
                nml.write("&main_nml" + '\n')
                nml.write("   obs_grid = '%s' " % (obs_grid) + '\n')
                nml.write("   interp_grid = '%s' " % (interp_grid) + '\n')
                nml.write("   obs_in_file = '%s.nc' " % (obs_in_file) + '\n')
                nml.write("   obs_nc_var = '%s' " % (obs_nc_var) + '\n')
                nml.write("   obs_out_file = '%s.nc' " % (ncl_obs_file) + '\n')
                nml.write("   nc_out_var = '%s' " % (obs_nc_var) + '\n')
                nml.write("   mask_file = '%s' " % (hgt_mask) + '\n')
                nml.write("/" + '\n')
                nml.write("&interp_nml" + '\n')
                nml.write("   obs_grid = '%s' " % (obs_grid) + '\n')
                nml.write("   interp_grid = '%s' " % (interp_grid) + '\n')
                nml.write("   interp_method = '%s' " % (interp_method) + '\n')
                nml.write("   interp_func = '%s' " % (interp_func) + '\n')
                nml.write("   interp_opts = ")
                for opt in interp_opts:
                    nml.write('%s, ' % opt)
                nml.write('\n')
                nml.write("/" + '\n')
                nml.close()

                # Call cref_interp to create interpolated obs and model states
                cmd = '%s/cref_interp %s obs' % (exec_dir,nml_file)
                print cmd
                os.system(cmd)
                
                # Call NCL program to create obs graphic
                cmd = """ncl 'INFILENAME="%s.nc"' 'FIELDNAME="obs"' 'OUTFILENAME="%s"' %s/plot_cref.ncl""" % (ncl_obs_file,ncl_obs_file,script_dir)
                print cmd
                os.system(cmd)
                os.system("mv %s.000001.png %s.png" % (ncl_obs_file,ncl_obs_file))
            
        else:
            print 'mosaic file missing'

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
