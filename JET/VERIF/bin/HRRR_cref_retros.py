#!/usr/bin/env python
#=====================================================================================
# This script will create output verification grids and statistics.
#
# By: Patrick Hofmann
# Last Update: 21 SEP 2010
#
# To execute: ./HRRR_cref_retros.py
#
#-------------------------------------start-------------------------------------------
import sys
import os
import resource
from datetime import datetime
from datetime import timedelta

def main():
    # Get environment variables
    Year       = os.getenv("YEAR")
    Month      = os.getenv("MONTH")
    Day        = os.getenv("DAY")
    valid_time = os.getenv("HOUR")

    exec_dir   = os.getenv("EXECDIR")
    rt_dir     = os.getenv("REALTIMEDIR")
    script_dir = os.getenv("SCRIPTDIR")
    obs_dir    = os.getenv("OBSDIR")
    
    model_grid  = os.getenv("MODELGRID")
    obs_grid    = os.getenv("OBSGRID")
    interp_grid = os.getenv("INTERPGRID")

    statfile    = os.getenv("STATF")
    
    # Looping variables
    leads          = os.getenv("FCSTLEADS")
    forecast_leads = leads.split()
    thresholds     = ['15','20','25','30','35','40','45']

    # Interpolation options
    opts        = os.getenv("IPOPTS")
    interp_opts = opts.split()
    
    # Static variables
    interp_method = 'neighbor-budget'
    interp_func   = 'average'

    # interp_method can be: bilinear, bicubic, neighbor, budget, spectral, neighbor-budget
    # interp_func   can be: average, maxval
    
    obs_nc_var = 'cref'
    model_nc_var = 'var0_16_196_localleveltype2000'
    nc_out_var = 'cref'
    obs_file = 'nssl_mosaic'
    
    #--------------------------------End Definitions------------------------------------

    # First, set stacksize to 512MB
    resource.setrlimit(resource.RLIMIT_STACK,(1600000000,1600000000))
    
    # Make new dir for this verification grid
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,valid_time)
    print valid_dir
    os.chdir('%s/%s' % (rt_dir,valid_dir))
    os.system('mkdir %s' % interp_grid)
    os.chdir(interp_grid)
    
    # open statistics files and add Headers
    c_ascii_file = '%s_conus_statistics.txt' % (statfile)
    w_ascii_file = '%s_west_statistics.txt' % (statfile)
    e_ascii_file = '%s_east_statistics.txt' % (statfile)
    #print c_ascii_file
    statf = open(c_ascii_file,'w')
    statf.write('LeadTime   Threshold    Hits      Misses      FAs       CNs        Bias     CSI      POD      FAR      ETS      HK       HSS\n')
    statf.write('============================================================================================================================================\n')
    statf.close()

    statf = open(w_ascii_file,'w')
    statf.write('LeadTime   Threshold    Hits      Misses      FAs       CNs        Bias     CSI      POD      FAR      ETS      HK       HSS\n')
    statf.write('============================================================================================================================================\n')
    statf.close()

    statf = open(e_ascii_file,'w')
    statf.write('LeadTime   Threshold    Hits      Misses      FAs       CNs        Bias     CSI      POD      FAR      ETS      HK       HSS\n')
    statf.write('============================================================================================================================================\n')
    statf.close()

    ncl_obs_file = '%s_%s' % (obs_file,interp_grid)

    nml_file = '%s.nml' % statfile
    main_nml_file= '%s_main.nml' % statfile
    verif_nml_file='%s_verif.nml' % statfile
    
    for forecast_lead in forecast_leads:
        print forecast_lead
        print os.getcwd()
        
        # Use built-in Date/Time modules
        t = datetime(int(Year),int(Month),int(Day),int(valid_time))
        delta_t = timedelta(hours=-int(forecast_lead))
        ff_t = t + delta_t
        
        ff_file = 'hrrr_%s%02d%02d%02dz+%s' % (ff_t.year,ff_t.month,ff_t.day,ff_t.hour,forecast_lead)
        ncl_model_file = '%s_%s' % (ff_file,interp_grid)

        # Write namelist
        nml = open(main_nml_file,'w')
        nml.write("&main_nml" + '\n')
        nml.write("   model_grid = '%s' " % (model_grid) + '\n')
        nml.write("   interp_grid = '%s' " % (interp_grid) + '\n')
        nml.write("   model_in_file = '../%s.nc' " % (ff_file) + '\n')
        nml.write("   model_nc_var = '%s' " % (model_nc_var) + '\n')
        nml.write("   model_out_file = '%s.nc' " % (ncl_model_file) + '\n')
        nml.write("   obs_out_file = '%s/%s/%s.nc' " % (obs_dir,valid_dir,ncl_obs_file) + '\n')
        nml.write("   nc_out_var = '%s' " % (nc_out_var) + '\n')
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

        print '../%s.nc' % ff_file
        print '%s/%s.nc' % (obs_dir,ncl_obs_file)

        # Call cref_interp to create interpolated obs and model states
        if(os.path.isfile('../%s.nc' % ff_file) and os.path.isfile('%s/%s/%s.nc' % (obs_dir,valid_dir,ncl_obs_file))):
            cmd = '%s/cref_interp %s model' % (exec_dir,main_nml_file)
            print cmd
            os.system(cmd)

        print interp_grid
                                    
        for threshold in thresholds:
            grid_file = '%s_vs_%s_%sdBZ_%sverif_grids.nc' %  (obs_file,ff_file,threshold,interp_grid)
            ncl_verif_file = '%s_vs_%s_%sdBZverif_%s' % (obs_file,ff_file,threshold,interp_grid)
            
            print grid_file

            nml = open(verif_nml_file,'w')
            nml.write("&verif_nml" + '\n')
            nml.write("   threshold = %s " % (threshold) + '\n')
            nml.write("   verif_out_file = '%s.nc' " % (ncl_verif_file) + '\n')
            nml.write("   conus_out_file = '%s' " % (c_ascii_file) + '\n')
            nml.write("   west_out_file = '%s' " % (w_ascii_file) + '\n')
            nml.write("   east_out_file = '%s' " % (e_ascii_file) + '\n')
            nml.write("/" + '\n')
            nml.close()

            os.system('cat %s %s > %s' % (main_nml_file,verif_nml_file,nml_file))
            
            if(os.path.isfile('%s.nc' % ncl_model_file) and os.path.isfile('%s/%s/%s.nc' % (obs_dir,valid_dir,ncl_obs_file))):
                # Write Forecast Lead and Threshold into output statistics files
                statf = open(c_ascii_file,'a')
                statf.write('   %s         %s   ' % (forecast_lead,threshold))
                statf.close()
                
                statf = open(w_ascii_file,'a')
                statf.write('   %s         %s   ' % (forecast_lead,threshold))
                statf.close()
                
                statf = open(e_ascii_file,'a')
                statf.write('   %s         %s   ' % (forecast_lead,threshold))
                statf.close()
                
                # Call cref_verif to do verification grid and statistics
                cmd = '%s/cref_verif %s' % (exec_dir,nml_file)
                print cmd
                os.system(cmd)
                        
                if(threshold == thresholds[0]):
                    # Call NCL program to create model graphic
                    cmd = """ncl 'INFILENAME="%s.nc"' 'FIELDNAME="model"' 'OUTFILENAME="%s"' %s/plot_cref.ncl""" % (ncl_model_file,ncl_model_file,script_dir)
                    print cmd
                    os.system(cmd)
                    os.system("mv %s.000001.png %s.png" % (ncl_model_file,ncl_model_file))
                # Call NCL program to create verif graphic
                cmd = """ncl 'INFILENAME="%s.nc"' 'FIELDNAME="verif"' 'OUTFILENAME="%s"' %s/plot_cref.ncl""" % (ncl_verif_file,ncl_verif_file,script_dir)
                print cmd
                os.system(cmd)
                os.system("mv %s.000001.png %s.png" % (ncl_verif_file,ncl_verif_file))
                
            else:
                print 'Either obs file or model file is missing to do verification'

                # Write Forecast Lead and Threshold into output statistics files
                statf = open(c_ascii_file,'a')
                statf.write('   %s         %s       -999       -999       -999       -999   |  -999     -999     -999     -999     -999     -999     -999\n' % (forecast_lead,threshold))
                statf.close()

                statf = open(w_ascii_file,'a')
                statf.write('   %s         %s       -999       -999       -999       -999   |  -999     -999     -999     -999     -999     -999     -999\n' % (forecast_lead,threshold))
                statf.close()

                statf = open(e_ascii_file,'a')
                statf.write('   %s         %s       -999       -999       -999       -999   |  -999     -999     -999     -999     -999     -999     -999\n' % (forecast_lead,threshold))
                statf.close()
                
                
    os.chdir('..')


#----------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
