#!/usr/bin/env python
#======================================================================================
# This script will create output verification grids and statistics for HRRR, RR and RUC
#
# By: Patrick Hofmann
# Last Update: 10 NOV 2010
#
# To execute: ./24h_precip_3hr.py
#
#-------------------------------------start--------------------------------------------
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

    exec_dir   = os.getenv("EXECDIR")
    script_dir = os.getenv("SCRIPTDIR")
    rt_dir     = os.getenv("REALTIMEDIR")
    obs_dir    = os.getenv("OBSDIR")
    model_dir  = os.getenv("MODELDIR")
    
    model_grid  = os.getenv("MODELGRID")
    interp_grid = os.getenv("INTERPGRID")

    statfile    = os.getenv("STATF")
    model       = os.getenv("MODEL")
    
    # Looping variables
    thresholds     = ['0.01','0.10','0.25','0.50','1.00','1.50','2.00','3.00']

    valid_time = '12'
    
    # Interpolation options
    opts        = os.getenv("IPOPTS")
    interp_opts = opts.split()
    
    # Static variables
    interp_method = 'neighbor-budget'
    interp_func   = 'average'

    # interp_method can be: bilinear, bicubic, neighbor, budget, spectral, neighbor-budget
    # interp_func   can be: average, maxval
    
    obs_nc_var = 'precip'
    model_nc_var = 'APCP_surface'
    nc_out_var = 'precip'
    obs_file = 'cpc_precip'

    ncl_dir = '/opt/ncl/5.2.0_bin'

    ff_files = []
    forecast_leads = ['12','03']
    #-----------------------------End of Definitions-----------------------------------

    # First, set stacksize to 800MB
    resource.setrlimit(resource.RLIMIT_STACK,(1600000000,1600000000))

    # Set environment variable to fix NCL 5.2 bug
    os.putenv("UDUNITS2_XML_PATH",'%s/lib/ncarg/udunits/udunits2.xml' % ncl_dir)
    
    if (model == 'rr'):
        ncl_model = 'RR'
    elif (model == 'ruc'):
        ncl_model = 'RUC'
    else:
        ncl_model = 'HRRR'
    
    # Make new dir for this verification grid
    valid_dir = '%s%s%s-12z' % (Year,Month,Day)
    print valid_dir
    
    if (not os.path.isdir('%s/%s' % (rt_dir,valid_dir))):
        os.system('mkdir -p %s/%s' % (rt_dir,valid_dir))
    
    os.chdir('%s/%s' % (rt_dir,valid_dir))

    #-------------------Create 24hr Sums--------------------------------
    # First, need to add up hourly totals, then sum across totals to get 24hr amount.
     
    # Use built-in Date/Time modules
    t         = datetime(int(Year),int(Month),int(Day),int(valid_time))

    # Do  12z+12 and 00z+12 for 2 forecast 24h verification
    sum_files = []
    for i in range(1,3):
        # Calculate offset
        delta_t = timedelta(hours=-int(forecast_leads[0])*i)
        init_t  = t + delta_t

        init_dir  = '%4d%02d%02d-%02dz' % (init_t.year,init_t.month,init_t.day,init_t.hour)
        init_file = '%s_%4d%02d%02d%02dz+%s.nc' % (model,init_t.year,init_t.month,init_t.day,init_t.hour,forecast_leads[0])
        
        sum_files.append('%s/%s/%s' % (model_dir,init_dir,init_file))

    # Now, add two 12hr totals together
    ff_files.append('%s_2fcst_24hr_total' % model)
    cmd = '%s/add_precip_totals %d %s %s %s.nc' % (exec_dir,len(sum_files),sum_files[0],sum_files[1],ff_files[0])
    print cmd
    os.system(cmd)

    # Do  12z+3, 15z+3, 18z+3, 21z+3, 00z+3, 03z+3, 06z+3, and 09z+3 for 8 forecast 24h verification
    sum_files = []
    for i in range(1,9):
        # Calculate offset
        delta_t = timedelta(hours=-int(forecast_leads[1])*i)
        init_t  = t + delta_t

        init_dir  = '%4d%02d%02d-%02dz' % (init_t.year,init_t.month,init_t.day,init_t.hour)
        init_file = '%s_%4d%02d%02d%02dz+%s.nc' % (model,init_t.year,init_t.month,init_t.day,init_t.hour,forecast_leads[1])
                
        sum_files.append('%s/%s/%s' % (model_dir,init_dir,init_file))

    # Now, add eight 3hr totals together
    ff_files.append('%s_8fcst_24hr_total' % model)
    cmd = '%s/add_precip_totals %d %s %s %s %s %s %s %s %s %s.nc' % (exec_dir,len(sum_files),sum_files[0],sum_files[1],sum_files[2],sum_files[3],sum_files[4],sum_files[5],sum_files[6],sum_files[7],ff_files[1])
    print cmd
    os.system(cmd)

    #-------------------Done 24hr Sums--------------------------------
    
    os.system('mkdir -p %s' % interp_grid)
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

    nml_file = '%s.nml' % statfile
    main_nml_file= '%s_main.nml' % statfile
    verif_nml_file='%s_verif.nml' % statfile

    for (ff_file,forecast_lead) in zip(ff_files,forecast_leads):
        if (forecast_lead == '03'):
            type = '3hr_totals'
        else:
            type = '12hr_totals'
        
        ncl_obs_file = '%s_%s' % (obs_file,interp_grid)
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
        nml.write("   valid_time = '%s%s%s12' " % (Year,Month,Day) + '\n')
        nml.write("   initial_time = '%04d%02d%02d%02d' " % (init_t.year,init_t.month,init_t.day,init_t.hour) + '\n')
        nml.write("   forecast_time = '%s' " % (forecast_lead) + '\n')
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
        
        # Call precip_interp to create interpolated obs and model states
        if(os.path.isfile('../%s.nc' % ff_file) and os.path.isfile('%s/%s/%s.nc' % (obs_dir,valid_dir,ncl_obs_file))):
            cmd = '%s/precip_interp %s model' % (exec_dir,main_nml_file)
            print cmd
            os.system(cmd)

        print interp_grid
        
        for threshold in thresholds:
            grid_file = '%s_vs_%s_%sin_%sverif_grids.nc' %  (obs_file,ff_file,threshold,interp_grid)
            ncl_verif_file = '%s_vs_%s_%sin_verif_%s' % (obs_file,ff_file,threshold,interp_grid)
            
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
                
                # Call do_verif to do verification grid and statistics
                cmd = '%s/do_verif %s' % (exec_dir,nml_file)
                print cmd
                os.system(cmd)

                if(threshold == thresholds[0]):
                    # Call NCL program to create model graphic
                    cmd = """ncl 'INFILENAME="%s.nc"' 'MODEL="%s"' 'FIELDNAME="model"' 'TYPE="%s"' 'OUTFILENAME="%s"' %s/plot_precip.ncl""" % (ncl_model_file,ncl_model,type,ncl_model_file,script_dir)
                    print cmd
                    os.system(cmd)
                    os.system("mv %s.000001.png %s.png" % (ncl_model_file,ncl_model_file))
                    os.system("convert -trim +repage %s.png %s.png" % (ncl_model_file,ncl_model_file))
                    os.system("convert -bordercolor black -border 15x15 %s.png %s.png" % (ncl_model_file,ncl_model_file))
                    os.system("convert -quality 90 -depth 8 %s.png %s.png" % (ncl_model_file,ncl_model_file))
                # Call NCL program to create verif graphic
                cmd = """ncl 'INFILENAME="%s.nc"' 'MODEL="%s"' 'FIELDNAME="verif"' 'TYPE="%s"' 'OUTFILENAME="%s"' %s/plot_precip.ncl""" % (ncl_verif_file,ncl_model,type,ncl_verif_file,script_dir)
                print cmd
                os.system(cmd)
                os.system("mv %s.000001.png %s.png" % (ncl_verif_file,ncl_verif_file))
                os.system("convert -trim +repage %s.png %s.png" % (ncl_verif_file,ncl_verif_file))
                os.system("convert -bordercolor black -border 15x15 %s.png %s.png" % (ncl_verif_file,ncl_verif_file))
                os.system("convert -quality 90 -depth 8 %s.png %s.png" % (ncl_verif_file,ncl_verif_file))
                
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
