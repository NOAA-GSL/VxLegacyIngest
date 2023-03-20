#!/usr/bin/env python
#======================================================================================
# This script will retrieve the grib2 NSSL mosaic file and then interpolate the 1km
# grid into all the necessary scales, along with plot each field.
#
# By: Jeff Hamilton
# Last Update: 20 DEC 2016
#
# To execute: ./NSSL_interp_new.py
#
# Example NSSL file: 
#
#---------------------------------------start-------------------------------------------
import sys
import os
import resource
from datetime import datetime
from datetime import timedelta
import subprocess
import fnmatch

def main():
    Year       = os.getenv("YEAR")
    Month      = os.getenv("MONTH")
    Day        = os.getenv("DAY")
    valid_time = os.getenv("HOUR")

    exec_dir   = os.getenv("EXECDIR")

    script_dir = os.getenv("SCRIPTDIR")
    nssl_dir   = os.getenv("REALTIMEDIR")
    obs_dir    = os.getenv("OBSDIR")
    hpss_dir    = os.getenv("HPSSDIR")
   
    interp_exec = os.getenv("INTERPEXEC")
    ncl_script  = os.getenv("NCLSCRIPT")
 
    hrrr_mask   = os.getenv("HRRRMASK")
    nssl_mask   = os.getenv("NSSLMASK")
    
    nssl_var    = os.getenv("NSSLVAR") 
    obs_nc_var  = os.getenv("OBSVAR") 
    obs_nc_var_out  = os.getenv("NC_OBSVAR") 
    grib2_var   = os.getenv("GRIB2VAR") 
    
    # Interpolation options
    orig_interp_opts = (os.getenv("IPOPTS")).split()

    # Static variables
    orig_obs_grid     = '01kmCE'
    interp_grids      = ['03kmLC','03kmLCrrfs','13kmLC','20kmLC','40kmLC','80kmLC'] 
    interp_grid_opts      = [2,2,2,4,8,16]

    interp_method = 'neighbor-budget'
    interp_func   = 'average'
    
    mosaic_file = 'nssl_mosaic'
    orig_nml_file = 'input.nml'
    model = 'NSSL'
    
    #-----------------------------End of Definitions--------------------------------

    # First, set stacksize to 800MB
    resource.setrlimit(resource.RLIMIT_STACK,(1600000000,1600000000))

    # Grab archived file from HPSS and unzip if necessary
    os.chdir('%s' % (obs_dir))
   
    print(valid_time)
 
    remainder = int(valid_time)%3

    if remainder is 0:
      archive_zip = "%s%s%s%s00.zip" % (Year,Month,Day,valid_time)
      cmd = "/apps/hpss/hsi get %s/%s" % (hpss_dir,archive_zip)
      print(cmd)
      os.system(cmd)
      if (os.path.isfile(archive_zip)):
        cmd = "/bin/unzip -o %s" % archive_zip
        print(cmd)
        os.system(cmd)
      else:
        print("Archived zip file failed to downlad! Could be missing! Exiting")
        sys.exit("Can't continue without archived file!")
        
    else:
      print("No archived file to grab at this valid hour. Moving on")

    # Unzip secondary compressed file that contains the final grib2 files

    second_zip = "%s%s%s%s00.zip" % (Year,Month,Day,valid_time)
    
    if (os.path.isfile("%s/%s" % (obs_dir,second_zip))):
      cmd = "/bin/unzip -o %s" % second_zip
      print(cmd)
      os.system(cmd)
    else:
        print 'secondary zipped file missing! Exiting'
        sys.exit("Can't continue without archived reflectivity file!")

    # Construct valid dir under run dir
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,valid_time)
    print valid_dir
    if (not os.path.isdir('%s/%s' % (nssl_dir,valid_dir))):
        os.mkdir('%s/%s' % (nssl_dir,valid_dir))
    os.chdir('%s/%s' % (nssl_dir,valid_dir))

    # Retrieve grib2 file and convert to netcdf
    grib_search = '%s%s%s-%s*.MRMS_%s_00.50_%s%s%s-%s*.grib2' % (Year,Month,Day,valid_time,nssl_var,Year,Month,Day,valid_time)
    cmd = 'ls %s/%s' % (obs_dir,grib_search)
    print cmd
    grib = find(grib_search,obs_dir)
    print grib
    #grib = subprocess.Popen([cmd], stdout=subprocess.PIPE).communicate()[0]
    #grib      = '%s/%s' % (obs_dir,grib_file)

    print grib
    cmd = 'cp %s %s.grib2' % (grib,mosaic_file)
    print cmd
    os.system(cmd)
    cmd = 'wgrib2 %s | egrep "(%s)" | wgrib2 -i %s -netcdf %s.nc' % (grib,grib2_var,grib,mosaic_file)
    print cmd
    os.system(cmd)
        
    # Interpolate to different projections
    if (os.path.isfile('%s.nc' % mosaic_file)):
        
        cmd = 'ln -sf nssl_mosaic.nc nssl_mosaic_01kmCE.nc'
        print cmd
        os.system(cmd)
        
        obs_grid    = orig_obs_grid
        interp_opts = orig_interp_opts
        
        for (interp_grid,i) in zip(interp_grids,interp_grid_opts):
            
            if (interp_grid == '03kmLC' or interp_grid == '13kmLC' or interp_grid == '03kmLCrrfs'):
                hgt_mask = nssl_mask
            else:
                hgt_mask = hrrr_mask
                
            if (interp_grid == '20kmLC' or interp_grid == '40kmLC' or interp_grid == '80kmLC'):
                obs_grid = '03kmLC'
                
            interp_opts[0] = i

            if (obs_grid == '03kmLC'):
                obs_nc_var = obs_nc_var_out

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
            nml.write("   nc_out_var = '%s' " % (obs_nc_var_out) + '\n')
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
            if (obs_grid == '03kmLC'):
               cmd = '%s/%s %s obs' % (exec_dir,interp_exec,nml_file)
               print cmd
               os.system(cmd)
              # os.system('rm %s' % nml_file)
            else:
               cmd = '%s/%s %s obs_grib2' % (exec_dir,interp_exec,nml_file)
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

    # Remove all files downlaoded from HPSS

    os.chdir('%s' % (obs_dir))
    cmd = "rm -rf %s%s%s%s*" % (Year,Month,Day,valid_time)
    print(cmd)
    os.system(cmd)
    cmd = "rm -rf %s%s%s-%s*" % (Year,Month,Day,valid_time)
    print(cmd)
    os.system(cmd)
    cmd = "rm -rf alaska conus guam conusPlus hawaii" % (Year,Month,Day,valid_time)
    print(cmd)
    os.system(cmd)


#-------------- find ----------------

def find(pattern, path):
    result = []
    for root, dirs, files in os.walk(path):
        for name in files:
            if fnmatch.fnmatch(name, pattern):
                result.append(os.path.join(root, name))
    return result[0]

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
