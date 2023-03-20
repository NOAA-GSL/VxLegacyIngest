#!/usr/bin/env python
#======================================================================================
# This script will first retrieve, then convert and ungrib the RCPF probability files
# The files when then be interpolated to 4km and 80km for RCPF vs NCWD verification.
#
# By: Patrick Hofmann
# Last Update: 28 SEP 2011
#
# To execute: ./RCPF_interp.py
#
# Example RCPF file: bck2cnpdf.YYYYMMDDHHFF
#---------------------------------------start-------------------------------------------
import sys
import os
import resource
from datetime import datetime
from datetime import timedelta
from datetime import date

def main():
    # Get environment variables
    Year        = os.getenv("YEAR")
    Month       = os.getenv("MONTH")
    Day         = os.getenv("DAY")
    init_time   = os.getenv("HOUR")

    exec_dir    = os.getenv("EXECDIR")
    script_dir  = os.getenv("SCRIPTDIR")
    rt_dir      = os.getenv("REALTIMEDIR")
    model_dir   = os.getenv("MODELDIR")

    # Looping variables
    forecast_leads = (os.getenv("FORECASTLEADS")).split()
    
    # Static variables
    interp_opts    = [2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1]
    model_grid     = 'ruc_20km'
    ncl_title      = 'RCPF'
    interp_grids   = ['03kmLC']
    resols         = ['3KM']
    nml_file       = 'input.nml'
    model_nc_var   = 'TSTM_surface'
    nc_out_var     = 'prob'
    model_file     = 'rcpf'

    interp_methods = ['neighbor-budget']
    interp_func    = 'average'
    
    cnvgrib        = '/home/rtrr/RR13/exec/UPP/cnvgrib.exe -g12 -p32'
    grib2_var      = 'TSTM'

    #-----------------------------End of Definitions--------------------------------

    # Construct init dir under run dir
    # Use built-in Date/Time modules
    t = datetime(int(Year),int(Month),int(Day),int(init_time))
    init_str  = t.strftime('%Y%m%d%H')
    init_dir = '%s-%sz' % (t.strftime('%Y%m%d'),t.strftime('%H'))
    print init_dir

    if (not os.path.isdir('%s/%s' % (rt_dir,init_dir))):
        os.system('mkdir -p %s/%s' % (rt_dir,init_dir))
    
    os.chdir('%s/%s' % (rt_dir,init_dir))
    
    for forecast_lead in forecast_leads:
        print forecast_lead
        delta_t = timedelta(hours=int(forecast_lead))
        ff_t = t + delta_t

        # RCPF format: YYYYMMDDHHFF
        valid_str = ff_t.strftime('%Y%m%d%H')

        # Get model data
        forecast_file = 'bck2cnpdf.%s%02d' % (init_str,int(forecast_lead))

        new_file = '%s_%sz+%02d' % (model_file,init_str,int(forecast_lead))

        if (True): #os.path.isfile('%s/%s' % (model_dir,forecast_file))):
            # Copy file to working dir
            cmd = 'cp %s/%s .' % (model_dir,forecast_file)
            print cmd
            #os.system(cmd)

            # Convert from grib11 to grib2
            cmd = '%s %s %s.grib2' % (cnvgrib,forecast_file,new_file)
            print cmd
            #os.system(cmd)

            # Remove GRIB1 file
            #os.remove(forecast_file)
            
            # Ungrib RCPF file into NetCDF, remove grib2 file
            cmd = 'wgrib2 %s.grib2 | egrep "%s" | wgrib2 -i %s.grib2 -netcdf %s.nc' %  \
                  (new_file,grib2_var,new_file,new_file)
            print cmd
            #os.system(cmd)
            #os.remove('%s.grib2' % new_file)

            # Interpolate native grid
            for (interp_grid,resol,interp_method) in zip(interp_grids,resols,interp_methods):
                if (not os.path.isdir('%s' % interp_grid)):
                    os.mkdir('%s' % interp_grid)
                os.chdir('%s' % interp_grid)
                
                #ncl_model_file = '%s_%s' % (new_file,interp_grid)
                #nml_file     = '%s_%s' % (interp_grid,orig_nml_file)
            
                # Write namelist
                nml = open(nml_file,'w')
                nml.write("&main_nml" + '\n')
                nml.write("   model_grid = '%s' " % (model_grid) + '\n')
                nml.write("   interp_grid = '%s' " % (interp_grid) + '\n')
                nml.write("   model_in_file = '../%s.nc' " % (new_file) + '\n')
                nml.write("   model_nc_var = '%s' " % (model_nc_var) + '\n')
                nml.write("   model_out_file = '%s.nc' " % (new_file) + '\n')
                nml.write("   nc_out_var = '%s' " % (nc_out_var) + '\n')
                nml.write("   valid_time = '%s' " % (valid_str) + '\n')
                nml.write("   initial_time = '%s' " % (init_str) + '\n')
                nml.write("   forecast_time = '%02d' " % (int(forecast_lead)) + '\n')
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
                cmd = '%s/prob_interp %s model' % (exec_dir,nml_file)
                print cmd
                os.system(cmd)
                #os.system('rm -rf %s' % nml_file)
                
                # Call NCL program to create obs graphic
                cmd = """ncl 'INFILENAME="%s.nc"' 'MODEL="%s"' 'FIELDNAME="model"' 'NCVAR="%s"' 'RES="%s"' 'TITLEVAR="Convective Probability"' 'OUTFILENAME="%s"' %s/plot_prob.ncl""" % (new_file,ncl_title,nc_out_var,resol,new_file,script_dir)
                print cmd
                os.system(cmd)
                os.system("mv %s.000001.png %s.png" % (new_file,new_file))
                os.system("convert -trim +repage %s.png %s.png" % (new_file,new_file))
                os.system("convert -bordercolor black -border 15x15 %s.png %s.png" % (new_file,new_file))
                os.system("convert -quality 90 -depth 8 %s.png %s.png" % (new_file,new_file))

                os.chdir('..')
        else:
            print 'forecast file missing: %s/%s' % (model_dir,forecast_file)
            
    os.chdir('..')

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
