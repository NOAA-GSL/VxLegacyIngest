#!/usr/bin/env python
#=======================================================================================
# This script will retrieve and process a CCFP text file into 3 separate forecast files.
# These files are NetCDF, and mapped onto the NCWD grid. The forecasts are then plotted.
#
# By: Patrick Hofmann
# Last Update: 31 MAR 2011
#
# To execute: ./CCFP_interp.py
#
# Example CCFP file: 20110323_17Z.idl
# Recent files kept on disk at: /public/data/rtvs/ccfp/final
#
#---------------------------------------start-------------------------------------------
import sys
import os
import resource
from datetime import datetime
from datetime import timedelta

def main():
    Year        = os.getenv("YEAR")
    Month       = os.getenv("MONTH")
    Day         = os.getenv("DAY")
    valid_time  = os.getenv("HOUR")

    static_dir  = os.getenv("STATICDIR")
    exec_dir    = os.getenv("EXECDIR")
    script_dir  = os.getenv("SCRIPTDIR")
    rt_dir      = os.getenv("REALTIMEDIR")
    src_dir     = os.getenv("SRCDIR")

    # Static variables
    model_file  = 'ccfp_%s%s%s%sz' % (Year,Month,Day,valid_time)
    forecasts   = ['04','06','08']
    nssl_file   = 'nssl_hgt_mask.nc'
    
    model_grid  = '01kmCE'
    interp_grid = '03kmLC'
    
    model_nc_var  = 'cov_conf' 
    nml_file      = 'ccfp.nml'
    model         = 'CCFP'   
 
    interp_method = 'neighbor-budget'
    interp_func   = 'average'
    interp_opts    = [2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1]
    #-----------------------------End of Definitions--------------------------------
    
    # Construct valid dir under run dir
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,valid_time)
    print valid_dir

    if (valid_time=='03' or valid_time=='05' or valid_time=='23'):
        sys.exit()
    if (not os.path.isdir('%s/%s' % (rt_dir,valid_dir))):
        os.system('mkdir -p %s/%s' % (rt_dir,valid_dir))
    os.chdir('%s/%s' % (rt_dir,valid_dir))
    
    # Copy source CCFP file to directory
    src_file = '%s%s%s_%sZ.idl' % (Year,Month,Day,valid_time)
    cmd = 'cp %s/%s .' % (src_dir,src_file)
    os.system(cmd)
    
    
    # Grid the text file into 3 separate forecast files (2h,4h,& 6h)
    cmd = '%s/grid_ccfp %s %s/%s %s' % (exec_dir,src_file,static_dir,nssl_file,model_file)
    print cmd
    os.system(cmd)
    #os.system('rm %s' % src_file)
    
    # Plot the 3 forecasts
    #for ff in forecasts:
    #    ff_file = '%s+%s.nc' % (model_file,ff)
    #    img_file = '%s+%s' % (model_file,ff)
    #    if (os.path.isfile('%s' % ff_file)):
            
            # Call NCL program to create obs graphic
    #        cmd = """ncl 'INFILENAME="%s"' 'OUTFILENAME="%s"' 'GRID="03km"' %s/plot_ccfp.ncl""" % (ff_file,img_file,script_dir)
    #        print cmd
    #        os.system(cmd)
    #        os.system("convert -trim +repage %s.png %s.png" % (img_file,img_file))
    #        os.system("convert -bordercolor white -border 15x15 %s.png %s.png" % (img_file,img_file))
    #        os.system("convert -quality 90 -depth 8 %s.png %s.png" % (img_file,img_file))
    #    else:
    #        print 'CCFP file missing'

    # Interpolate 1kmCE grid to 03kmLC (HRRR grid)
    os.system('mkdir -p %s' % interp_grid)
    os.chdir('%s' % interp_grid)

    for ff in forecasts:
        ff_file = '%s+%s.nc' % (model_file,ff)
        img_file = '%s+%s' % (model_file,ff)
        if (os.path.isfile('../%s' % ff_file)):
            # Write namelist
            nml = open(nml_file,'w')
            nml.write("&main_nml" + '\n')
            nml.write("   model_grid = '%s' " % (model_grid) + '\n')
            nml.write("   interp_grid = '%s' " % (interp_grid) + '\n')
            nml.write("   model_in_file = '../%s' " % (ff_file) + '\n')
            nml.write("   model_nc_var = '%s' " % (model_nc_var) + '\n')
            nml.write("   model_out_file = '%s' " % (ff_file) + '\n')
            nml.write("   nc_out_var = '%s' " % (model_nc_var) + '\n')
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
    
	    # Call prob_interp to create interpolated state
	    cmd = '%s/prob_interp %s model' % (exec_dir,nml_file)
	    print cmd
	    os.system(cmd)
    
	    # Call NCL program to create model graphic
	    cmd = """ncl 'INFILENAME="%s"' 'FIELDNAME="model"' 'MODEL="%s"' 'OUTFILENAME="%s"' %s/plot_ccfp.ncl""" % (ff_file,model,img_file,script_dir)
	    print cmd
	    os.system(cmd)
	    os.system("convert -trim +repage %s.png %s.png" % (img_file,img_file))
	    os.system("convert -bordercolor white -border 15x15 %s.png %s.png" % (img_file,img_file))
	    os.system("convert -quality 90 -depth 8 %s.png %s.png" % (img_file,img_file))
    

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
