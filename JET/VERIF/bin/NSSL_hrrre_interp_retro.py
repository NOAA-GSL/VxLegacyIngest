#!/usr/bin/env python
#======================================================================================
# This script will retrieve and stitch together the new 4 NSSL tiles into 1 mosaic file,
# and then interpolate the 1km grid into all the necessary scales, along with plot
# each field.
#
# By: Patrick Hofmann
# Last Update: 08 AUG 2013
#
# To execute: ./NSSL_hrrre_interp.py
#
# Example NSSL file: 20100428-120000.netcdf.gz
# Recent (1-2 days) dir: /public/data/radar/nssl/mrms_binary/tileX/VAR.YYYYMMDD.HH0000.gz
# Archive dir: /arch2/fdr/YYYY/MM/DD/data/radar/nssl/mrms_binary/tileX/VAR.YYYYMMDDHH0000.gz
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
    valid_time = os.getenv("HOUR")

    exec_dir   = os.getenv("EXECDIR")

    script_dir = os.getenv("SCRIPTDIR")
    nssl_dir   = os.getenv("REALTIMEDIR")
    obs_dir    = os.getenv("OBSDIR")
   
    interp_exec = os.getenv("INTERPEXEC")
    ncl_script  = os.getenv("NCLSCRIPT")
 
    hrrre_c_mask   = os.getenv("HRRREMASK_C")
    hrrre_s_mask   = os.getenv("HRRREMASK_S")
    hrrre_se_mask   = os.getenv("HRRREMASK_SE")
    hrrre_ne_mask   = os.getenv("HRRREMASK_NE")
    hrrre_n_mask   = os.getenv("HRRREMASK_N")
    nssl_mask   = os.getenv("NSSLMASK")
    
    nssl_var    = os.getenv("NSSLVAR") 
    nssl_subdir = os.getenv("NSSLSUBDIR") 
    obs_nc_var  = os.getenv("OBSVAR") 
    
    # Interpolation options
    orig_interp_opts = (os.getenv("IPOPTS")).split()

    # Static variables
    orig_obs_grid     = '01kmCE'
    interp_grids      = ['03kmLC','03kmLC_C','03kmLC_S','03kmLC_NE','03kmLC_SE','03kmLC_N'] 
   # interp_grids      = ['03kmLC_NE'] 

    interp_method = 'neighbor-budget'
    interp_func   = 'average'
    
    mosaic_file = 'nssl_mosaic'
    orig_nml_file = 'input.nml'
    model = 'NSSL'
    
    #-----------------------------End of Definitions--------------------------------

    # First, set stacksize to 800MB
    resource.setrlimit(resource.RLIMIT_STACK,(1600000000,1600000000))

    # Construct valid dir under run dir
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,valid_time)
    print valid_dir
    if (not os.path.isdir('%s/%s' % (nssl_dir,valid_dir))):
        os.mkdir('%s/%s' % (nssl_dir,valid_dir))
    os.chdir('%s/%s' % (nssl_dir,valid_dir))

    # Copy already existing mosaic file
    retro_file = '%s/%s%s%s%s/nssl_mosaic.nc' % (obs_dir,Year,Month,Day,valid_time)
    os.system('cp %s .' % retro_file)

    # Retrieve, decompress, and rename tiles
#    for i in range(1,5):
#        # Copy and unzip file
#        tile_file = '%s.%s%s%s.%s0000' % (nssl_var,Year,Month,Day,valid_time)
#        tile      = '%s/tile%d/%s/%s' % (obs_dir,i,nssl_subdir,tile_file)
#        print tile_file, tile
#        os.system('cp %s.gz .' % tile)
#        os.system('gunzip %s.gz' % tile_file)
#        os.system('mv %s tile_%d.bin' % (tile_file,i))
        
    # Stitch them together into one NetCDF file
#    cmd = '%s/nssl_binary2nc . %s %s.nc' % (exec_dir,obs_nc_var,mosaic_file)
#    print cmd
#    os.system(cmd)
    #os.system('rm tile*.bin')
    
    if (os.path.isfile('%s.nc' % mosaic_file)):
        
        cmd = 'ln -sf nssl_mosaic.nc nssl_mosaic_01kmCE.nc'
        print cmd
        os.system(cmd)
        
        obs_grid    = orig_obs_grid
        interp_opts = orig_interp_opts
        
        for (interp_grid,i) in zip(interp_grids,range(0,5)):
            
            if (interp_grid == '03kmLC_C'):
                hgt_mask = nssl_mask
            elif (interp_grid == '03kmLC_S'):
                hgt_mask = nssl_mask
            elif (interp_grid == '03kmLC_SE'):
                hgt_mask = nssl_mask
            elif (interp_grid == '03kmLC_NE'):
                hgt_mask = nssl_mask
            elif (interp_grid == '03kmLC_N'):
                hgt_mask = nssl_mask
            else:
                hgt_mask = nssl_mask
                
           # if (i >= 2):
           #     obs_grid = '03kmLC'
                
            if (i == 1):
                interp_opts[0] = 8
            else:
                interp_opts[0] = 2 ** i
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
            nml.write("   valid_time = '%s%s%s%s' " % (Year,Month,Day,valid_time) + '\n')
            nml.write("/" + '\n')
            nml.write("&interp_nml" + '\n')
            nml.write("   interp_method = '%s' " % (interp_method) + '\n')
            nml.write("   interp_func = '%s' " % (interp_func) + '\n')
            nml.write("   interp_opts = ")
            for opt in interp_opts:
                nml.write('%s, ' % opt)
            nml.write('\n')
            nml.write("/" + '\n')
            nml.close()

            # Call interp exec to create interpolated obs and model states
            cmd = '%s/%s %s obs' % (exec_dir,interp_exec,nml_file)
            print cmd
            os.system(cmd)
           # os.system('rm %s' % nml_file)
            
            # Call NCL program to create obs graphic
            cmd = """ncl 'INFILENAME="%s.nc"' 'FIELDNAME="obs"' 'MODEL="%s"' 'OUTFILENAME="%s"' %s/%s""" % (ncl_obs_file,model,ncl_obs_file,script_dir,ncl_script)
            print cmd
            os.system(cmd)
            os.system("mv %s.000001.png %s.png" % (ncl_obs_file,ncl_obs_file))
            os.system("convert -trim +repage %s.png %s.png" % (ncl_obs_file,ncl_obs_file))
            if (nssl_var == 'cref'):
                os.system("convert -bordercolor black -border 15x15 %s.png %s.png" % (ncl_obs_file,ncl_obs_file))
            else:
                os.system("convert -bordercolor white -border 15x15 %s.png %s.png" % (ncl_obs_file,ncl_obs_file))
            os.system("convert -quality 90 -depth 8 %s.png %s.png" % (ncl_obs_file,ncl_obs_file))
    else:
        print 'mosaic file missing'

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
