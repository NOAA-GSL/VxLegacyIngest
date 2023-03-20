#!/usr/bin/env python
#======================================================================================
# This script will first retrieve the NCWD files closest to the top of the hour and
# then plot the field
#
# By: Patrick Hofmann
# Last Update: 25 FEB 2011
#
# To execute: ./NCWD_interp.py
#
# Example NCWD file: 1021721210000 --NetCDF files
# Recent (1-3 days) dir: /public/data/rtvs/grids/ncwf/255/netcdf
#---------------------------------------start-------------------------------------------
import sys
import os
import resource
from datetime import datetime
from datetime import timedelta
from datetime import date

def main():
    # Get environment variables
    Year       = os.getenv("YEAR")
    Month      = os.getenv("MONTH")
    Day        = os.getenv("DAY")
    valid_time = os.getenv("HOUR")

    exec_dir   = os.getenv("EXECDIR")
    script_dir = os.getenv("SCRIPTDIR")
    ncwd_dir   = os.getenv("REALTIMEDIR")
    obs_dir    = os.getenv("OBSDIR")

    mask_file  = os.getenv("MASK")

    # Interpolation options
    opts        = os.getenv("IPOPTS")
    interp_opts = opts.split()

    # Static variables
    model          = 'NCWD'
    obs_file       = 'ncwd'
    obs_grid       = 'ncwd_04km'
    interp_grids   = ['ncwd_04km','ncwd_80km']

    interp_method  = 'neighbor-budget'
    interp_func    = 'maxval'
    
    obs_in_nc_var  = 'cwdi'
    obs_out_nc_var = 'vip'

    orig_nml_file = 'input.nml'
    #-----------------------------End of Definitions--------------------------------

    # First, set stacksize to 512MB
    #resource.setrlimit(resource.RLIMIT_STACK,(800000000,800000000))
    
    # Construct valid dir under run dir
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,valid_time)
    print valid_dir
    if (not os.path.isdir('%s/%s' % (ncwd_dir,valid_dir))):
        os.mkdir('%s/%s' % (ncwd_dir,valid_dir))
    os.chdir('%s/%s' % (ncwd_dir,valid_dir))

    # Retreive NCWD file closest to top of hour
    t = datetime(int(Year),int(Month),int(Day),int(valid_time))
    for i in range(0,3):
        delta_t = timedelta(minutes=int(i))
        hi_t = t + delta_t
        lo_t = t - delta_t
        hi_ncwd = '%s/%s0000' % (obs_dir,hi_t.strftime('%y%j%H%M'))
        lo_ncwd = '%s/%s0000' % (obs_dir,lo_t.strftime('%y%j%H%M'))
        print hi_ncwd
        print lo_ncwd
        if (os.path.isfile(hi_ncwd)):
            #cmd = 'cp %s ncwd_%4d%02d%02d%02dz.nc' % (hi_ncwd,t.year,t.month,t.day,t.hour)
            cmd = 'cp %s %s.nc' % (hi_ncwd,obs_file)
            print cmd
            os.system(cmd)
            break
        if (os.path.isfile(lo_ncwd)):
            #cmd = 'cp %s ncwd_%4d%02d%02d%02dz.nc' % (lo_ncwd,t.year,t.month,t.day,t.hour)
            cmd = 'cp %s %s.nc' % (lo_ncwd,obs_file)
            print cmd
            os.system(cmd)
            break

    if (os.path.isfile('%s.nc' % obs_file)):

        for (i,interp_grid) in zip(range(0,2),interp_grids):
            ncl_obs_file = '%s' % interp_grid
            nml_file     = '%s_%s' % (interp_grid,orig_nml_file)

            interp_opts[0] = 8*i + 2
            
            # Write namelist
            nml = open(nml_file,'w')
            nml.write("&main_nml" + '\n')
            nml.write("   obs_grid = '%s' " % (obs_grid) + '\n')
            nml.write("   interp_grid = '%s' " % (interp_grid) + '\n')
            nml.write("   obs_in_file = '%s.nc' " % (obs_file) + '\n')
            nml.write("   obs_nc_var = '%s' " % (obs_in_nc_var) + '\n')
            nml.write("   obs_out_file = '%s.nc' " % (ncl_obs_file) + '\n')
            nml.write("   nc_out_var = '%s' " % (obs_out_nc_var) + '\n')
            nml.write("   valid_time = '%s%s%s%s' " % (Year,Month,Day,valid_time) + '\n')
            nml.write("   mask_file = '%s' " % (mask_file) + '\n')
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
            
            # Call vip_interp to create interpolated state
            cmd = '%s/vip_interp %s obs' % (exec_dir,nml_file)
            print cmd
            os.system(cmd)
            
            # Call NCL program to create obs graphic
            cmd = """ncl 'INFILENAME="%s.nc"' 'FIELDNAME="obs"' 'MODEL="%s"' 'OUTFILENAME="%s"' %s/plot_vip.ncl""" % (ncl_obs_file,model,ncl_obs_file,script_dir)
            print cmd
            os.system(cmd)
            os.system("mv %s.000001.png %s.png" % (ncl_obs_file,ncl_obs_file))
            os.system("convert -trim +repage %s.png %s.png" % (ncl_obs_file,ncl_obs_file))
            os.system("convert -bordercolor black -border 15x15 %s.png %s.png" % (ncl_obs_file,ncl_obs_file))
            os.system("convert -quality 90 -depth 8 %s.png %s.png" % (ncl_obs_file,ncl_obs_file))
    
    
#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
