#!/usr/bin/env python
#======================================================================================
# This script will create output verification grids and statistics for HRRR, RR and RUC
#
# By: Patrick Hofmann
# Last Update: 2 OCT 2012
#
# To execute: ./sub24h_precip_verif.py
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
    
    # Ensemble Members
    members = (os.getenv("ENSEMBLE_MEMBERS")).split()
    
    # Static variables
    interp_method = 'neighbor-budget'
    interp_func   = 'average'

    # interp_method can be: bilinear, bicubic, neighbor, budget, spectral, neighbor-budget
    # interp_func   can be: average, maxval
    
    obs_nc_var   = 'precip'
    model_nc_var = 'APCP_surface'
    nc_out_var   = 'precip'
    in_obs_file  = 'stageIV_6hr_precip'
    ncl_obs      = 'StageIV 2 6HR Totals'
    obs_file     = '%s_%s' % (in_obs_file,interp_grid)

    ff_files = []
    #accum_lens = ['01','06','12']
    accum_lens = ['06','12']
    #-----------------------------End of Definitions-----------------------------------

    # Make new dir for this verification grid
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,valid_time)
    print valid_dir

    if (not os.path.isdir('%s/%s/%s' % (rt_dir,valid_dir,interp_grid))):
        os.system('mkdir -p %s/%s/%s' % (rt_dir,valid_dir,interp_grid))
        
    os.chdir('%s/%s/%s' % (rt_dir,valid_dir,interp_grid))
    
    # Use built-in Date/Time modules
    t = datetime(int(Year),int(Month),int(Day),int(valid_time))

    # Select subdomains for statistical calculations
    do_conus = False
    do_west  = False
    do_east  = True
    do_ne    = True
    do_se    = True

    # Create logical and file arrays
    bools = [do_conus,do_west,do_east,do_ne,do_se]
    boolstrs = ['do_conus','do_west','do_east','do_ne','do_se']
    
    sfiles = []
    sfileos = []

    nml_file = []
    main_nml_file = []
    verif_nml_file = []

    for member in members:
      m_index = members.index(member)

      postpend = 'sub24hr_statistics.txt'
      c_file = '%s_mem%s_conus_%s' % (statfile,member,postpend)
      w_file = '%s_mem%s_west_%s' % (statfile,member,postpend)
      e_file = '%s_mem%s_east_%s' % (statfile,member,postpend)
      ne_file = '%s_mem%s_ne_%s' % (statfile,member,postpend)
      se_file = '%s_mem%s_se_%s' % (statfile,member,postpend)

      postpend2 = 'out_file'
      c_fileo = 'conus_%s' % (postpend2)
      w_fileo = 'west_%s' % (postpend2)
      e_fileo = 'east_%s' % (postpend2)
      ne_fileo = 'ne_%s' % (postpend2)
      se_fileo = 'se_%s' % (postpend2)

      sfiles_mem = [c_file,w_file,e_file,ne_file,se_file]
      sfileos_mem = [c_fileo,w_fileo,e_fileo,ne_fileo,se_fileo]
      sfiles.append(sfiles_mem)
      sfileos.append(sfileos_mem)

      # open statistics files and add Headers
      for (bool,sfile) in zip(bools,sfiles[m_index]):
        if(bool):
            statf = open(sfile,'w')
            statf.write('LeadTime   Threshold    Hits      Misses      FAs       CNs        Bias     CSI      POD      FAR      ETS      HK       HSS\n')
            statf.write('============================================================================================================================================\n')
            statf.close()

      nml_file_mem = '%s_mem%s.nml' % (statfile,member)
      main_nml_file_mem = '%s_mem%s_main.nml' % (statfile,member)
      verif_nml_file_mem ='%s_mem%s_verif.nml' % (statfile,member)

      nml_file.append(nml_file_mem)
      main_nml_file.append(main_nml_file_mem)
      verif_nml_file.append(verif_nml_file_mem)


    #-------------------Setup done--------------------------------

    for member in members:
      m_index = members.index(member)
      for accum_len in accum_lens:
        print 'Forecast Accumulation Length: ', accum_len
        
        # Get model file
        if (int(accum_len) == 1):
            ff_file        = '%shr_totals_mem%s.nc' % (accum_len,member)
            ncl_model_file = '%shr_totals_%s_mem%s' % (accum_len,interp_grid,member)

            sum_files = []
            for i in range(1,7):
                delta_t = timedelta(hours=-i)
                init_t  = t + delta_t
            	init_dir  = '%4d%02d%02d-%02dz' % (init_t.year,init_t.month,init_t.day,init_t.hour)
            	init_file = '%s_mem%s_%4d%02d%02d%02dz' % (model,member,init_t.year,init_t.month,init_t.day,init_t.hour)
                ff = '%s/%s/%s_%shr_total.nc' % (model_dir,init_dir,init_file,accum_len)
                print ff
                sum_files.append(ff)

            # Add 6 1hr fcst totals together
            cmd = '%s/add_precip_totals %s %d' % (exec_dir,model_nc_var,len(sum_files))
            for i in range(0,6):
                cmd += ''.join(' %s' % sum_files[i])
            cmd += ' %s' % ff_file
            print cmd
            os.system(cmd)

        else:
            delta_t = timedelta(hours=-int(accum_len))
            init_t  = t + delta_t

            init_dir  = '%4d%02d%02d-%02dz' % (init_t.year,init_t.month,init_t.day,init_t.hour)
            init_file = '%s_mem%s_%4d%02d%02d%02dz' % (model,member,init_t.year,init_t.month,init_t.day,init_t.hour)
                        
            ff_file        = '%s/%s/%s_%shr_total.nc' % (model_dir,init_dir,init_file,accum_len)
            ncl_model_file = '%s_%shr_total_%s' % (init_file,accum_len,interp_grid)

        # Get obs file
        if (int(accum_len) > 6):
            sum_files = []
            for i in range(0,2):
                # Calculate offset
                delta_t = timedelta(hours=-6+int(6*i))
                init_t  = t + delta_t
                
                init_dir  = '%4d%02d%02d-%02dz' % (init_t.year,init_t.month,init_t.day,init_t.hour)
                init_file = '%s/%s/%s.nc' % (obs_dir,init_dir,obs_file)
                print init_file
                sum_files.append(init_file)

            # Now, add two 6hr totals together
            ncl_obs_file = '%s_12hr_total_%s' % (in_obs_file,interp_grid)
            cmd = '%s/add_precip_totals %s %d' % (exec_dir,obs_nc_var,len(sum_files))
            for i in range(0,2):
                cmd += ''.join(' %s' % sum_files[i])
            cmd += ' %s.nc' % ncl_obs_file
            print cmd
            os.system(cmd)
        else:
            src_obs_file = '%s/%s/%s.nc' % (obs_dir,init_dir,obs_file)
            ncl_obs_file = '%s_06hr_total_%s' % (in_obs_file,interp_grid)
            cmd = 'cp %s %s.nc' % (src_obs_file,ncl_obs_file)
            print cmd
            os.system(cmd)
        
        # Write namelist
        nml = open(main_nml_file[m_index],'w')
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
            cmd = '%s/precip_interp %s model' % (exec_dir,main_nml_file[m_index])
            print cmd
            os.system(cmd)
            
        print interp_grid
        
        for threshold in thresholds:
            grid_file = '%s_vs_%s_%sin_%s_verif_grids.nc' %  (in_obs_file,ncl_model_file,threshold,interp_grid)
            ncl_verif_file = '%s_vs_%s_%sin_verif_%s' % (in_obs_file,ncl_model_file,threshold,interp_grid)
            
            print grid_file
            
            nml = open(verif_nml_file[m_index],'w')
            nml.write("&verif_nml" + '\n')
            nml.write("   threshold = %s " % (threshold) + '\n')
            nml.write("   verif_out_file = '%s.nc' " % (ncl_verif_file) + '\n')
            for (bool,boolstr,sfile,sfileo) in zip(bools,boolstrs,sfiles[m_index],sfileos[m_index]):
                if(bool):
                    nml.write("   %s = .true. " % boolstr + '\n')                
                    nml.write("   %s = '%s' " % (sfileo,sfile) + '\n')
            nml.write("/" + '\n')
            nml.close()
            
            os.system('cat %s %s > %s' % (main_nml_file[m_index],verif_nml_file[m_index],nml_file[m_index]))
            
            if(os.path.isfile('%s.nc' % ncl_model_file) and os.path.isfile('%s.nc' % (ncl_obs_file))):
                # Write Forecast Length and Threshold into output statistics files
                for (bool,sfile) in zip(bools,sfiles[m_index]):
                    if(bool):
                        statf = open(sfile,'a')
                        statf.write('   %s         %s   ' % (accum_len,threshold))
                        statf.close()
                        
                # Call do_verif to do verification grid and statistics
                cmd = '%s/do_verif %s' % (exec_dir,nml_file[m_index])
                print cmd
                os.system(cmd)
                
            else:
                print 'Either obs file or model file is missing to do verification'
                
                # Write Forecast Length and Threshold into output statistics files
                for (bool,sfile) in zip(bools,sfiles[m_index]):
                    if(bool):
                        statf = open(sfile,'a')
                        statf.write('   %s         %s       -999       -999       -999       -999   |  -999     -999     -999     -999     -999     -999     -999\n' % (accum_len,threshold))
                        statf.close()
                
#    os.system('rm *nml')
#    os.system('rm *nc')

#----------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
