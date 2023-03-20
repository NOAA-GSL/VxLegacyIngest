#!/usr/bin/env python
#======================================================================================
# This script will create output verification grids and statistics for HRRR, RR and RUC
#
# By: Patrick Hofmann
# Last Update: 10 NOV 2010
#
# To execute: ./24h_precip_verif.py
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
    ncl_obs      = 'StageIV 4 6HR Totals'
    obs_file     = '%s_%s' % (in_obs_file,interp_grid)

    ncl_dir = '/opt/ncl/5.2.0_bin'

    ff_files = []
    #forecast_lens = ['24','12','03','01']
    forecast_lens = ['24','12']
    #-----------------------------End of Definitions-----------------------------------

    #print 'RLIMIT_STACK', resource.getrlimit(resource.RLIMIT_STACK)

    # First, set stacksize to 800MB
    resource.setrlimit(resource.RLIMIT_STACK,(1600000000,1600000000))

    #print 'RLIMIT_STACK',resource.getrlimit(resource.RLIMIT_STACK)

    # Set environment variable to fix NCL 5.2 bug
    os.putenv("UDUNITS2_XML_PATH",'%s/lib/ncarg/udunits/udunits2.xml' % ncl_dir)
    
    # Make new dir for this verification grid
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,valid_time)
    print valid_dir

    if (not os.path.isdir('%s/%s' % (rt_dir,valid_dir))):
        os.system('mkdir -p %s/%s' % (rt_dir,valid_dir))
        
    os.chdir('%s/%s' % (rt_dir,valid_dir))

    #-------------------Create 24hr Sums--------------------------------
    # First, need to add up hourly totals, then sum across totals to get 24hr amount.
    
    for member in members:

      ff_files.append([])
      m_index = members.index(member) 
      # Use built-in Date/Time modules
      t = datetime(int(Year),int(Month),int(Day),int(valid_time))

      # Do  12z+24 for 1 forecast 24h verification
      delta_t = timedelta(hours=-24)
      init_t  = t + delta_t

      init_dir  = '%4d%02d%02d-%02dz' % (init_t.year,init_t.month,init_t.day,init_t.hour)
      init_file = '%s_mem%s_%4d%02d%02d%02dz' % (model,member,init_t.year,init_t.month,init_t.day,init_t.hour)
      cmd = 'cp %s/%s/%s_24hr_total.nc ./%s_mem%s_1fcst_24hr_total.nc' % (model_dir,init_dir,init_file,model,member)
      print cmd
      os.system(cmd)
      ff_files[m_index].append('%s_mem%s_1fcst_24hr_total' % (model,member))

      # Do  12z+12 and 00z+12 for 2 forecast 24h verification
      sum_files = []
      for i in range(1,3):
        # Calculate offset
        delta_t = timedelta(hours=-int(forecast_lens[1])*i)
        init_t  = t + delta_t

        init_dir  = '%4d%02d%02d-%02dz' % (init_t.year,init_t.month,init_t.day,init_t.hour)
        init_file = '%s_mem%s_%4d%02d%02d%02dz' % (model,member,init_t.year,init_t.month,init_t.day,init_t.hour)

        sum_files.append('%s/%s/%s_12hr_total.nc' % (model_dir,init_dir,init_file))

      # Now, add two 12hr totals together
      ff_files[m_index].append('%s_mem%s_2fcst_24hr_total' % (model,member))
      cmd = '%s/add_precip_totals %s %d %s %s %s.nc' % (exec_dir,model_nc_var,len(sum_files),sum_files[0],sum_files[1],ff_files[m_index][1])
      print cmd
      os.system(cmd)

      # Do  12z+3, 15z+3, 18z+3, 21z+3, 00z+3, 03z+3, 06z+3, and 09z+3 for 8 forecast 24h verification
      sum_files = []
      for i in range(1,9):
        # Calculate offset
        delta_t = timedelta(hours=-int(forecast_lens[2])*i)
        init_t  = t + delta_t

        init_dir  = '%4d%02d%02d-%02dz' % (init_t.year,init_t.month,init_t.day,init_t.hour)
        init_file = '%s_mem%s_%4d%02d%02d%02dz' % (model,member,init_t.year,init_t.month,init_t.day,init_t.hour)

        sum_files.append('%s/%s/%s_03hr_total.nc' % (model_dir,init_dir,init_file))

      # Now, add eight 3hr totals together
      ff_files[m_index].append('%s_mem%s_8fcst_24hr_total' % (model,member))
      cmd = '%s/add_precip_totals %s %d' % (exec_dir,model_nc_var,len(sum_files))
      for i in range(0,8):
        cmd += ''.join(' %s' % sum_files[i])
      cmd += ' %s.nc' % ff_files[m_index][2]
      print cmd
      os.system(cmd)

      # Do  12z+1, 13z+1, 14z+1, 15z+1, 16z+1, 17z+1, 18z+1, 19z+1, 20z+1, 21z+1, 22z+1, 23z+1,
      #     00z+1, 01z+1, 02z+1, 03z+1, 04z+1, 05z+1, 06z+1, 07z+1, 08z+1, 09z+1, 10z+1, 11z+1
      # for 24 forecast 24h verification
      sum_files = []
      for i in range(1,25):
        # Calculate offset
        delta_t = timedelta(hours=-int(forecast_lens[3])*i)
        init_t  = t + delta_t

        init_dir  = '%4d%02d%02d-%02dz' % (init_t.year,init_t.month,init_t.day,init_t.hour)
        init_file = '%s_mem%s_%4d%02d%02d%02dz' % (model,member,init_t.year,init_t.month,init_t.day,init_t.hour)
        
        sum_files.append('%s/%s/%s_01hr_total.nc' % (model_dir,init_dir,init_file))

      # Now, add twenty four 1hr totals together
      ff_files[m_index].append('%s_mem%s_24fcst_24hr_total' % (model,member))
      cmd = '%s/add_precip_totals %s %d' % (exec_dir,model_nc_var,len(sum_files))
      for i in range(0,24):
          cmd += ''.join(' %s' % sum_files[i])
      cmd += ' %s.nc' % ff_files[m_index][3]
      print cmd
      os.system(cmd)

    #-------------------Done 24hr Sums--------------------------------

    os.system('mkdir -p %s' % interp_grid)
    os.chdir(interp_grid)

    # Now add 6hr obs precip files to get 24hr sum
    for member in members:
      sum_files = []
      for i in range(0,4):
        # Calculate offset
        delta_t = timedelta(hours=-18+int(6*i))
        init_t  = t + delta_t
        
        init_dir  = '%4d%02d%02d-%02dz' % (init_t.year,init_t.month,init_t.day,init_t.hour)
        init_file = '%s/%s/%s.nc' % (obs_dir,init_dir,obs_file)
        print init_file
        sum_files.append(init_file)

      # Now, add four 6hr totals together
      ncl_obs_file = '%s_24hr_total_%s' % (in_obs_file,interp_grid)
      ff_files[m_index].append(ncl_obs_file)
      cmd = '%s/add_precip_totals %s %d' % (exec_dir,obs_nc_var,len(sum_files))
      for i in range(0,4):
        cmd += ''.join(' %s' % sum_files[i])
      cmd += ' %s.nc' % ff_files[m_index][4]
      print cmd
      os.system(cmd)

    # Call NCL program to create obs graphic
    cmd = """ncl 'INFILENAME="%s.nc"' 'MODEL="%s"' 'TYPE="stageIV"' 'FIELDNAME="obs"' 'OUTFILENAME="%s"' %s/plot_precip.ncl""" % (ncl_obs_file,ncl_obs,ncl_obs_file,script_dir)
    print cmd
    os.system(cmd)
    os.system("mv %s.000001.png %s.png" % (ncl_obs_file,ncl_obs_file))
    os.system("convert -trim +repage %s.png %s.png" % (ncl_obs_file,ncl_obs_file))
    os.system("convert -bordercolor black -border 15x15 %s.png %s.png" % (ncl_obs_file,ncl_obs_file))
    
    # Create subdomain files

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

      postpend = 'statistics.txt'
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

    for member in members:
      m_index = members.index(member)
      for (ff_file,forecast_len) in zip(ff_files[m_index],forecast_lens):
        if (forecast_len == '01'):
            type = '1hr_totals'
        elif (forecast_len == '03'):
            type = '3hr_totals'
        elif (forecast_len == '12'):
            type = '12hr_totals'
        else:
            type = '24hr_totals'
        
        ncl_model_file = '%s_%s' % (ff_file,interp_grid)
        
        # Write namelist
        nml = open(main_nml_file[m_index],'w')
        nml.write("&main_nml" + '\n')
        nml.write("   model_grid = '%s' " % (model_grid) + '\n')
        nml.write("   interp_grid = '%s' " % (interp_grid) + '\n')
        nml.write("   model_in_file = '../%s.nc' " % (ff_file) + '\n')
        nml.write("   model_nc_var = '%s' " % (model_nc_var) + '\n')
        nml.write("   model_out_file = '%s.nc' " % (ncl_model_file) + '\n')
        nml.write("   obs_out_file = '%s.nc' " % (ncl_obs_file) + '\n')
        nml.write("   nc_out_var = '%s' " % (nc_out_var) + '\n')
        nml.write("   valid_time = '%s%s%s12' " % (Year,Month,Day) + '\n')
        nml.write("   initial_time = '%04d%02d%02d%02d' " % (init_t.year,init_t.month,init_t.day,init_t.hour) + '\n')
        nml.write("   forecast_time = '%s' " % (forecast_len) + '\n')
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
        print '%s.nc' % ncl_obs_file
        
        # Call precip_interp to create interpolated obs and model states
        if(os.path.isfile('../%s.nc' % ff_file) and os.path.isfile('%s.nc' % (ncl_obs_file))):
            cmd = '%s/precip_interp %s model' % (exec_dir,main_nml_file[m_index])
            print cmd
            os.system(cmd)
            
        print interp_grid
        
        for threshold in thresholds:
            grid_file = '%s_vs_%s_%sin_%sverif_grids.nc' %  (in_obs_file,ff_file,threshold,interp_grid)
            ncl_verif_file = '%s_vs_%s_%sin_verif_%s' % (in_obs_file,ff_file,threshold,interp_grid)
            
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
                        statf.write('   %s         %s   ' % (forecast_len,threshold))
                        statf.close()
                        
                # Call do_verif to do verification grid and statistics
                cmd = '%s/do_verif %s' % (exec_dir,nml_file[m_index])
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
                
                # Write Forecast Length and Threshold into output statistics files
                for (bool,sfile) in zip(bools,sfiles[m_index]):
                    if(bool):
                        statf = open(sfile,'a')
                        statf.write('   %s         %s       -999       -999       -999       -999   |  -999     -999     -999     -999     -999     -999     -999\n' % (forecast_len,threshold))
                        statf.close()
                
        #os.system('rm *nml')
        #os.system('rm *nc')

#----------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
