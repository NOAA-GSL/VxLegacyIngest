#!/usr/bin/env python
#======================================================================================
# This script will create output verification grids, images, and statistics for HRRR, RR and RUC
#
# By: Jeff Hamilton
# Last Update: 26 FEB 2019
#
# To execute: ./1h_precip_verif.py
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
    valid_time = os.getenv("HOUR")
    
    exec_dir   = os.getenv("EXECDIR")
    script_dir = os.getenv("SCRIPTDIR")
    rt_dir     = os.getenv("REALTIMEDIR")
    obs_dir    = os.getenv("OBSDIR")
    model_dir  = os.getenv("MODELDIR")
    
    model_grid  = os.getenv("MODELGRID")
    interp_grid = os.getenv("INTERPGRID")

    statfile    = os.getenv("STATF")
    model       = os.getenv("MODEL")
    ncl_model   = os.getenv("NCLMODEL")
    
    # Looping variables
    thresholds     = ['0.01','0.10','0.25','0.50','1.00','1.50','2.00','3.00']

    # Interpolation options
    interp_opts = (os.getenv("IPOPTS")).split()
   
    # Accumulation periods 
    accum_lens = (os.getenv("ACCUMLENS")).split()

    # Static variables
    interp_method = 'neighbor-budget'
    interp_func   = 'average'

    # interp_method can be: bilinear, bicubic, neighbor, budget, spectral, neighbor-budget
    # interp_func   can be: average, maxval
    
    obs_nc_var   = 'precip'
    model_nc_var = 'APCP_surface'
    nc_out_var   = 'precip'
    in_obs_file  = 'stageIV_1hr_precip'
    ncl_obs      = 'StageIV Totals'
    obs_file     = '%s_%s' % (in_obs_file,interp_grid)

    ff_files = []
    #-----------------------------End of Definitions-----------------------------------

    # Make new dir for this verification grid
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,valid_time)
    print valid_dir

    if (not os.path.isdir('%s/%s/%s' % (rt_dir,valid_dir,interp_grid))):
        os.system('mkdir -p %s/%s/%s' % (rt_dir,valid_dir,interp_grid))
        
    os.chdir('%s/%s/%s' % (rt_dir,valid_dir,interp_grid))
    
    # Use built-in Date/Time modules
    t = datetime(int(Year),int(Month),int(Day),int(valid_time))

    # Create subdomain files
    postpend = 'precip_statistics.txt'
    c_file = '%s_conus_%s' % (statfile,postpend)
    w_file = '%s_west_%s' % (statfile,postpend)
    e_file = '%s_east_%s' % (statfile,postpend)
    ne_file = '%s_ne_%s' % (statfile,postpend)
    se_file = '%s_se_%s' % (statfile,postpend)

    postpend2 = 'out_file'
    c_fileo = 'conus_%s' % (postpend2)
    w_fileo = 'west_%s' % (postpend2)
    e_fileo = 'east_%s' % (postpend2)
    ne_fileo = 'ne_%s' % (postpend2)
    se_fileo = 'se_%s' % (postpend2)

    # Select subdomains for statistical calculations
    do_conus = False
    do_west  = False
    do_east  = True
    do_ne    = True
    do_se    = True

    # Create logical and file arrays
    bools = [do_conus,do_west,do_east,do_ne,do_se]
    boolstrs = ['do_conus','do_west','do_east','do_ne','do_se']
    sfiles = [c_file,w_file,e_file,ne_file,se_file]
    sfileos = [c_fileo,w_fileo,e_fileo,ne_fileo,se_fileo]

    # open statistics files and add Headers
    for (bool,sfile) in zip(bools,sfiles):
        if(bool):
            statf = open(sfile,'w')
            statf.write('LeadTime   Threshold    Hits      Misses      FAs       CNs        Bias     CSI      POD      FAR      ETS      HK       HSS\n')
            statf.write('============================================================================================================================================\n')
            statf.close()  


    nml_file = '%s.nml' % statfile
    main_nml_file= '%s_main.nml' % statfile
    verif_nml_file='%s_verif.nml' % statfile


    #-------------------Setup done--------------------------------


    for accum_len in accum_lens:
        print 'Forecast Accumulation Length: ', accum_len
        
        type = '%dhr' % (int(accum_len))

        # Get model file
        init_dir  = '%4d%02d%02d-%02dz' % (t.year,t.month,t.day,t.hour)
        init_file = '%s_%4d%02d%02d%02dz' % (model,t.year,t.month,t.day,t.hour)
        ff_file        = '%s/%s/%s_%shr_total.nc' % (model_dir,init_dir,init_file,accum_len)

        ncl_model_file = '%s_%shr_total_%s' % (init_file,accum_len,interp_grid)

        # Add all obs files together for all desired forecast periods
        sum_files = []

        for i in range(0,int(accum_len)):
            delta_t = timedelta(hours=-i)
            init_t = t + delta_t

            init_dir  = '%4d%02d%02d-%02dz' % (init_t.year,init_t.month,init_t.day,init_t.hour)
            init_file = '%s/%s/%s.nc' % (obs_dir,init_dir,obs_file)
            print init_file
            sum_files.append(init_file)
         

        # Now, add the totals together
        ncl_obs_file = '%s_%dhr_%s' % (in_obs_file,int(accum_len),interp_grid)
        cmd = '%s/add_precip_totals %s %d' % (exec_dir,obs_nc_var,len(sum_files))
        for i in range(0,int(accum_len)):
            cmd += ''.join(' %s' % sum_files[i])
        cmd += ' %s.nc' % ncl_obs_file
        print cmd
        os.system(cmd)

        if(os.path.isfile('%s.nc' % ncl_obs_file)):
           print "Obs image exists"
        else:
           # Call NCL program to create obs graphic
           cmd = """ncl 'INFILENAME="%s.nc"' 'MODEL="%s"' 'TYPE="stageIV"' 'FIELDNAME="obs"' 'OUTFILENAME="%s"' %s/plot_sub24_precip.ncl""" % (ncl_obs_file,ncl_obs,ncl_obs_file,script_dir)
           print cmd
           os.system(cmd)
           os.system("mv %s.000001.png %s.png" % (ncl_obs_file,ncl_obs_file))
           os.system("convert -trim +repage %s.png %s.png" % (ncl_obs_file,ncl_obs_file))
           os.system("convert -bordercolor black -border 15x15 %s.png %s.png" % (ncl_obs_file,ncl_obs_file))
        
        # Write namelist
        nml = open(main_nml_file,'w')
        nml.write("&main_nml" + '\n')
        nml.write("   model_grid = '%s' " % (model_grid) + '\n')
        nml.write("   interp_grid = '%s' " % (interp_grid) + '\n')
        nml.write("   model_in_file = '%s' " % (ff_file) + '\n')
        nml.write("   model_nc_var = '%s' " % (model_nc_var) + '\n')
        nml.write("   model_out_file = '%s.nc' " % (ncl_model_file) + '\n')
        nml.write("   obs_out_file = '%s.nc' " % (ncl_obs_file) + '\n')
        nml.write("   nc_out_var = '%s' " % (nc_out_var) + '\n')
        nml.write("   valid_time = '%s%s%s12' " % (Year,Month,Day) + '\n')
        nml.write("   initial_time = '%04d%02d%02d%02d' " % (init_t.year,init_t.month,init_t.day,init_t.hour) + '\n')
        nml.write("   forecast_time = '%s' " % (accum_len) + '\n')
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
        
        print 'source model file: %s' % ff_file
        print 'new model file: %s.nc' % ncl_model_file
        print 'obs file: %s.nc' % ncl_obs_file
        
        # Call precip_interp to create interpolated obs and model states
        if(os.path.isfile(ff_file) and os.path.isfile('%s.nc' % (ncl_obs_file))):
            cmd = '%s/precip_interp %s model' % (exec_dir,main_nml_file)
            print cmd
            os.system(cmd)
            
        print interp_grid
        
        for threshold in thresholds:
            grid_file = '%s_vs_%s_%sin_%s_verif_grids.nc' %  (in_obs_file,ncl_model_file,threshold,interp_grid)
            ncl_verif_file = '%s_vs_%s_%sin_verif_%s' % (in_obs_file,ncl_model_file,threshold,interp_grid)
            
            print grid_file
            
            nml = open(verif_nml_file,'w')
            nml.write("&verif_nml" + '\n')
            nml.write("   threshold = %s " % (threshold) + '\n')
            nml.write("   verif_out_file = '%s.nc' " % (ncl_verif_file) + '\n')
            for (bool,boolstr,sfile,sfileo) in zip(bools,boolstrs,sfiles,sfileos):
                if(bool):
                    nml.write("   %s = .true. " % boolstr + '\n')                
                    nml.write("   %s = '%s' " % (sfileo,sfile) + '\n')
            nml.write("/" + '\n')
            nml.close()
            
            os.system('cat %s %s > %s' % (main_nml_file,verif_nml_file,nml_file))
            
            if(os.path.isfile('%s.nc' % ncl_model_file) and os.path.isfile('%s.nc' % (ncl_obs_file))):
                # Write Forecast Length and Threshold into output statistics files
                for (bool,sfile) in zip(bools,sfiles):
                    if(bool):
                        statf = open(sfile,'a')
                        statf.write('   %s         %s   ' % (accum_len,threshold))
                        statf.close()
                        
                # Call do_verif to do verification grid and statistics
                cmd = '%s/do_verif %s' % (exec_dir,nml_file)
                print cmd
                os.system(cmd)

                if(threshold == thresholds[0]):
                    # Call NCL program to create model graphic
                    cmd = """ncl 'INFILENAME="%s.nc"' 'MODEL="%s"' 'FIELDNAME="model"' 'TYPE="%s"' 'OUTFILENAME="%s"' %s/plot_sub24_precip.ncl""" % (ncl_model_file,ncl_model,type,ncl_model_file,script_dir)
                    print cmd
                    os.system(cmd)
                    os.system("mv %s.000001.png %s.png" % (ncl_model_file,ncl_model_file))
                    os.system("convert -trim +repage %s.png %s.png" % (ncl_model_file,ncl_model_file))
                    os.system("convert -bordercolor black -border 15x15 %s.png %s.png" % (ncl_model_file,ncl_model_file))
                    os.system("convert -quality 90 -depth 8 %s.png %s.png" % (ncl_model_file,ncl_model_file))
                # Call NCL program to create verif graphic
                cmd = """ncl 'INFILENAME="%s.nc"' 'MODEL="%s"' 'FIELDNAME="verif"' 'TYPE="%s"' 'OUTFILENAME="%s"' %s/plot_sub24_precip.ncl""" % (ncl_verif_file,ncl_model,type,ncl_verif_file,script_dir)
                print cmd
                os.system(cmd)
                os.system("mv %s.000001.png %s.png" % (ncl_verif_file,ncl_verif_file))
                os.system("convert -trim +repage %s.png %s.png" % (ncl_verif_file,ncl_verif_file))
                os.system("convert -bordercolor black -border 15x15 %s.png %s.png" % (ncl_verif_file,ncl_verif_file))
                os.system("convert -quality 90 -depth 8 %s.png %s.png" % (ncl_verif_file,ncl_verif_file))                
            else:
                print 'Either obs file or model file is missing to do verification'
                
                # Write Forecast Length and Threshold into output statistics files
                for (bool,sfile) in zip(bools,sfiles):
                    if(bool):
                        statf = open(sfile,'a')
                        statf.write('   %s         %s       -999       -999       -999       -999   |  -999     -999     -999     -999     -999     -999     -999\n' % (accum_len,threshold))
                        statf.close()
                
#    os.system('rm *nml')
#    os.system('rm *nc')

#----------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
