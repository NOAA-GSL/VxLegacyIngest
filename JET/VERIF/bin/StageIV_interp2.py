#!/usr/bin/env python
#======================================================================================
# This script will retrieve the 1hr StageIV precip (NetCDF) file,
# and then interpolate the lat/lon grid into all the necessary scales, combine all previous 
# forecast hours
#
# By: Jeff Hamilton
# Last Update: 25 FEB 2019
#
# To execute: ./StageIV_interp2.py
#
# Example StageIV file: YYDDDHH0000FF
# Recent (last month) dir: /public/data/precip/stage4/1hr/netcdf
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
    Hour       = os.getenv("HOUR")
    
    exec_dir   = os.getenv("EXECDIR")
    ncl_dir    = os.getenv("NCLDIR")
    script_dir = os.getenv("SCRIPTDIR")
    rt_dir     = os.getenv("REALTIMEDIR")
    obs_dir    = os.getenv("OBSDIR")

    pcp_mask  = os.getenv("PCPMASK")
    grib2_var  = "APCP"
    
    # Interpolation options
    orig_interp_opts = (os.getenv("IPOPTS")).split()

    # Static variables
    orig_obs_grid     = 'stageIV_04km'
    interp_grids      = ['03kmLC','03kmLCsar','13kmLC','20kmLC','40kmLC','80kmLC'] 

    interp_method = 'neighbor-budget'
    interp_func   = 'average'
    
    precip_file = 'stageIV_1hr_precip'
    precip_mask = 'stageIV_pcp_mask.nc'
    out_nc_var = 'precip'
    model = 'StageIV'

    orig_nml_file = 'input.nml'

    #ncl_dir = '/opt/ncl/5.2.0_bin'
    
    #-----------------------------End of Definitions--------------------------------

    resource.setrlimit(resource.RLIMIT_STACK,(800000000,800000000))
    
    tval = datetime(int(Year),int(Month),int(Day),int(Hour))

#    # Files named with reference time, so valid time is reference time plus forecast hour
#    tref = tval - timedelta(hours=1)
#    src_file = tref.strftime('%y%j%H000001')
    
    # Files now have a grib2 name with YYYYMMDDHH
    tref = tval - timedelta(hours=1)
    src_file = tref.strftime('st4_conus.%Y%m%d%H.01h')
    
    # Construct valid dir under run dir
    valid_dir = tval.strftime('%Y%m%d-%Hz')
    print valid_dir
    os.system('mkdir -p %s/%s' % (rt_dir,valid_dir))
    os.chdir('%s/%s' % (rt_dir,valid_dir))

    print 'Source file: %s/%s.grb2' % (obs_dir,src_file)

    if (os.path.isfile('%s/%s.grb2' % (obs_dir,src_file))):
        cmd = 'cp %s/%s.grb2 .' % (obs_dir,src_file)
        print cmd
        os.system(cmd)

        # Ungrib model file into NetCDF, remove grib2 file
        cmd = 'wgrib2 %s.grb2 | egrep "(%s)" | wgrib2 -i %s.grb2 -netcdf %s.nc' %  \
              (src_file,grib2_var,src_file,precip_file)
        print cmd
        os.system(cmd)
        os.remove('%s.grb2' % src_file)
    else:
        print '%s precip file missing' % model
    
    if (os.path.isfile('%s.nc' % precip_file)):

        obs_grid    = orig_obs_grid
        interp_opts = orig_interp_opts
        
        for (interp_grid,i) in zip(interp_grids,range(0,5)):
            if (i == 0):
                interp_opts[0] = 2
            else:
                interp_opts[0] = 2 ** i

            obs_in_file  = '%s' % (precip_file)
            obs_nc_var = 'APCP'
            #obs_in_file  = '%s_%s' % (precip_file,obs_grid)
            #obs_nc_var = 'precip'
                
            ncl_obs_file = '%s_%s' % (precip_file,interp_grid)
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
            nml.write("   nc_out_var = '%s' " % (out_nc_var) + '\n')
            nml.write("   valid_time = '%s%s%s%s' " % (Year,Month,Day,Hour) + '\n')
            nml.write("   mask_file = '%s' " % (pcp_mask) + '\n')
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

            # Call precip_interp to create interpolated obs states
            cmd = '%s/precip_interp %s obs' % (exec_dir,nml_file)
            print cmd
            os.system(cmd)
            os.system('rm -rf %s' % nml_file)
            
            # Call NCL program to create obs graphic
            cmd = """ncl 'INFILENAME="%s.nc"' 'MODEL="%s"' 'FIELDNAME="obs"' 'OUTFILENAME="%s"' %s/plot_precip.ncl""" % (ncl_obs_file,model,ncl_obs_file,ncl_dir)
            print cmd
            os.system(cmd)
            os.system("mv %s.000001.png %s.png" % (ncl_obs_file,ncl_obs_file))
            os.system("convert -trim +repage %s.png %s.png" % (ncl_obs_file,ncl_obs_file))
            os.system("convert -bordercolor black -border 15x15 %s.png %s.png" % (ncl_obs_file,ncl_obs_file))
            os.system("convert -quality 90 -depth 8 %s.png %s.png" % (ncl_obs_file,ncl_obs_file))
            
    else:
        print 'precip file missing'

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
