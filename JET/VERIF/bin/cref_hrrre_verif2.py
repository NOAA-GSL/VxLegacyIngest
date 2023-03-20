#!/usr/bin/env python
#======================================================================================
# This script will create output verification grids and statistics for HRRR, RR and RUC
#
# By: Patrick Hofmann
# Last Update: 16 JAN 2013
#
# To execute: ./cref_verif.py
#
#-------------------------------------start--------------------------------------------
import sys
import os
import resource
from datetime import datetime
from datetime import timedelta
import numpy

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
    interp_grid = os.getenv("INTERPGRID")

    statfile    = os.getenv("STATF")
    model       = os.getenv("MODEL")
    ncl_model   = os.getenv("NCLMODEL")
   
    # Looping variables
    leads          = os.getenv("FCSTLEADS")
    forecast_leads = leads.split()
    fcsts = len(forecast_leads)
    thresholds     = ['15','20','25','30','35','40','45']
    members = (os.getenv("ENSEMBLE_MEMBERS")).split()

    # Interpolation options
    opts        = os.getenv("IPOPTS")
    interp_opts = opts.split()
    
    # Static variables
    interp_method = 'neighbor-budget'
    interp_func   = 'average'

    # interp_method can be: bilinear, bicubic, neighbor, budget, spectral, neighbor-budget
    # interp_func   can be: average, maxval
    
    obs_nc_var = 'cref'
    nc_out_var = 'cref'
    obs_file = 'nssl_mosaic'

    #-----------------------------End of Definitions-----------------------------------

    if (model.startswith(('stmas','laps'))):
        model_nc_var = 'lmr'
    elif (model.startswith(('rap','ruc'))):
        model_nc_var = 'var0_16_196_localleveltype2000'
    else:
        model_nc_var = 'var0_16_196_entireatmosphere'
    
    if (model_grid == 'stmaslaps_conus_03km' and interp_grid == '03kmLC'):
        interp_method = 'neighbor'
    
    # Make new dir for this verification grid
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,valid_time)
    print valid_dir
    os.chdir('%s/%s' % (rt_dir,valid_dir))
    os.system('mkdir %s' % interp_grid)
    os.chdir(interp_grid)

    # Select subdomains for statistical calculations
    do_conus = False
    do_west  = False
    do_east  = False
    do_ne    = False
    do_se    = False
    do_ci    = False
    do_hwt   = False
    do_roc   = False

    if (model.startswith(('stmas-ci','laps-ci'))):
        do_ci = True
    elif (model.startswith(('stmas-hwt','laps-hwt'))):
        do_hwt = True
    elif (model.startswith(('stmas-roc','laps-roc'))):
        do_roc = True
    else:
        do_conus = False
        do_west  = False
        do_east  = True
        do_ne    = True
        do_se    = True
        do_ci    = True
        do_hwt   = True
        do_roc   = True

    bools = [do_conus,do_west,do_east,do_ne,do_se,do_ci,do_hwt,do_roc]
    boolstrs = ['do_conus','do_west','do_east','do_ne','do_se','do_ci','do_hwt','do_roc']

    # Create subdomain files for each member
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
       ci_file = '%s_mem%s_ci_%s' % (statfile,member,postpend)
       hwt_file = '%s_mem%s_hwt_%s' % (statfile,member,postpend)
       roc_file = '%s_mem%s_roc_%s' % (statfile,member,postpend)

       postpend2 = 'out_file'
       c_fileo = 'conus_%s' % (postpend2)
       w_fileo = 'west_%s' % (postpend2)
       e_fileo = 'east_%s' % (postpend2)
       ne_fileo = 'ne_%s' % (postpend2)
       se_fileo = 'se_%s' % (postpend2)
       ci_fileo = 'ci_%s' % (postpend2)
       hwt_fileo = 'hwt_%s' % (postpend2)
       roc_fileo = 'roc_%s' % (postpend2)

    # Create logical and file arrays
       sfiles_mem = [c_file,w_file,e_file,ne_file,se_file,ci_file,hwt_file,roc_file]
       sfileos_mem = [c_fileo,w_fileo,e_fileo,ne_fileo,se_fileo,ci_fileo,hwt_fileo,roc_fileo]
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

    ncl_obs_file = '%s_%s' % (obs_file,interp_grid)


    for member in members: 
      for forecast_lead in forecast_leads:
          m_index = members.index(member)
          print "MEMBER: ",member," FCST HOUR: ",forecast_lead
          print os.getcwd()
       
          of = ncl_obs_file
          nf = nml_file[m_index]
          mnf = main_nml_file[m_index]
          vnf = verif_nml_file[m_index]

        # Use built-in Date/Time modules
          t = datetime(int(Year),int(Month),int(Day),int(valid_time))
          delta_t = timedelta(hours=-int(forecast_lead))
          ff_t = t + delta_t
        
          ff_file = '%s_mem%04d_%s%02d%02d%02dz+%s' % (model,int(member),ff_t.year,ff_t.month,ff_t.day,ff_t.hour,forecast_lead)
          ncl_model_file = '%s_%s' % (ff_file,interp_grid)

        # Write namelist
          nml = open(main_nml_file[m_index],'w')
          nml.write("&main_nml" + '\n')
          nml.write("   model_grid = '%s' " % (model_grid) + '\n')
          nml.write("   interp_grid = '%s' " % (interp_grid) + '\n')
          nml.write("   model_in_file = '../%s.nc' " % (ff_file) + '\n')
          nml.write("   model_nc_var = '%s' " % (model_nc_var) + '\n')
          nml.write("   model_out_file = '%s.nc' " % (ncl_model_file) + '\n')
          nml.write("   obs_out_file = '%s/%s/%s.nc' " % (obs_dir,valid_dir,ncl_obs_file) + '\n')
          nml.write("   nc_out_var = '%s' " % (nc_out_var) + '\n')
          nml.write("   valid_time = '%s%s%s%s' " % (Year,Month,Day,valid_time) + '\n')
          nml.write("   initial_time = '%04d%02d%02d%02d' " % (ff_t.year,ff_t.month,ff_t.day,ff_t.hour) + '\n')
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

       # Call cref_interp to create interpolated obs and model states
          if(os.path.isfile('../%s.nc' % ff_file) and os.path.isfile('%s/%s/%s.nc' % (obs_dir,valid_dir,ncl_obs_file))):
              cmd = '%s/cref_hrrre_interp2 %s model' % (exec_dir,main_nml_file[m_index])
              print cmd
              os.system(cmd)

          print interp_grid
                                    
          for threshold in thresholds:
              grid_file = '%s_vs_%s_%sdBZ_%sverif_grids.nc' %  (obs_file,ff_file,threshold,interp_grid)
              ncl_verif_file = '%s_vs_%s_%sdBZverif_%s' % (obs_file,ff_file,threshold,interp_grid)
              
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
              
              print "NCL_MODEL_FILE: ", ncl_model_file, ".nc"
              print "OBS_FILE: ", obs_dir, "/", valid_dir, "/", ncl_obs_file
              
              if(os.path.isfile('%s.nc' % ncl_model_file) and os.path.isfile('%s/%s/%s.nc' % (obs_dir,valid_dir,ncl_obs_file))):
               # Write Forecast Lead and Threshold into output statistics files
                  for (bool,sfile) in zip(bools,sfiles[m_index]):
                    if(bool):
                       statf = open(sfile,'a')
                       statf.write('   %s         %s   ' % (forecast_lead,threshold))
                       statf.close()

               # Call do_verif to do verification grid and statistics
                  cmd = '%s/do_verif %s' % (exec_dir,nml_file[m_index])
                  print cmd
                  os.system(cmd)
                  
                  ncl_model_mem = ncl_model + "_mem00" + member
      
                  if(threshold == thresholds[0]):
                   # Call NCL program to create model graphic
                      cmd = """ncl 'INFILENAME="%s.nc"' 'MODEL="%s"' 'FIELDNAME="model"' 'OUTFILENAME="%s"' %s/plot_cref.ncl""" % (ncl_model_file,ncl_model_mem,ncl_model_file,script_dir)
                      print cmd
                      os.system(cmd)
                   #os.system("mv %s.000001.png %s.png" % (ncl_model_file,ncl_model_file))
                      os.system("convert -trim +repage %s.png %s.png" % (ncl_model_file,ncl_model_file))
                      os.system("convert -bordercolor black -border 15x15 %s.png %s.png" % (ncl_model_file,ncl_model_file))
                      os.system("convert -quality 90 -depth 8 %s.png %s.png" % (ncl_model_file,ncl_model_file))
                    
               # Call NCL program to create verif graphic
                  cmd = """ncl 'INFILENAME="%s.nc"' 'MODEL="%s"' 'FIELDNAME="verif"' 'OUTFILENAME="%s"' %s/plot_cref.ncl""" % (ncl_verif_file,ncl_model_mem,ncl_verif_file,script_dir)
                  print cmd
                  os.system(cmd)
                  #os.system("mv %s.000001.png %s.png" % (ncl_verif_file,ncl_verif_file))
                  os.system("convert -trim +repage %s.png %s.png" % (ncl_verif_file,ncl_verif_file))
                  os.system("convert -bordercolor black -border 15x15 %s.png %s.png" % (ncl_verif_file,ncl_verif_file))
                  os.system("convert -quality 90 -depth 8 %s.png %s.png" % (ncl_verif_file,ncl_verif_file))
                
              else:
                  print 'Either obs file or model file is missing to do verification'

               # Write Forecast Lead and Threshold into output statistics files
                  for (bool,sfile) in zip(bools,sfiles[m_index]):
                    if(bool):
                       statf = open(sfile,'a')
                       statf.write('   %s         %s       -999       -999       -999       -999   |  -999     -999     -999     -999     -999     -999     -999\n' % (forecast_lead,threshold))
                       statf.close()
                
#              os.system("rm %s.nc" % ncl_verif_file)
#       os.system('rm *.nml')
    os.chdir('..')


#----------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
