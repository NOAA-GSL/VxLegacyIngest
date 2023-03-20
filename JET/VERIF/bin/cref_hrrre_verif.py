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
from netCDF4 import Dataset

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

    # find out which domain we are using

    for member in members:

       grid_file = '%s/%s/%s_mem%04d_%s%02d%02d%02dz+00.nc' % (rt_dir,valid_dir,model,int(members[0]),int(Year),int(Month),int(Day),int(valid_time))
       print grid_file

       try:

          netcdf_file = Dataset(grid_file,"r")     

          int_lat = netcdf_file.variables['latitude'][0]
          int_lon = netcdf_file.variables['longitude'][0]

          lat = [ '%.4f' % value for value in int_lat ]
          lon = [ '%.4f' % value for value in int_lon ]

          max = len(lat) - 1

          print "Lat: ", lat[max], "Lon: ", lon[max]

          if lat[max] == "28.3031":
             postpend = 'statistics_central.txt'
             region = 'C'
          elif lat[max] == "23.4206":
             postpend = 'statistics_south.txt'
             region = 'S'
          elif lat[max] == "31.5267":
             postpend = 'statistics_northeast.txt'
             region = 'NE'
          elif lat[max] == "23.3694":
             postpend = 'statistics_southeast.txt'
             region = 'SE'
          elif lat[max] == "34.8041":
             postpend = 'statistics_north.txt'
             region = 'N'
          else:
             print "Can't find the region to use, exiting.."
             exit(2)      

       except:
          print "Error opening the netcdf file: ", grid_file


    # Create subdomain files
   # postpend = 'statistics.txt'
 
    sfiles = []
    sfileos = []

    for member in members:
      stat_file = '%s_mem%s_%s' % (statfile,member,postpend)

      postpend2 = 'out_file'
      stat_fileo = 'stat_%s' % (postpend2)


    # Create logical and file arrays
     # sfiles = [stat_file]
     # sfileos = [stat_fileo]
      sfiles.append(stat_file)
      sfileos.append(stat_fileo)    


    # open statistics files and add Headers
    for sfile in sfiles:
            statf = open(sfile,'w')
            statf.write('LeadTime   Threshold    Hits      Misses      FAs       CNs        Bias     CSI      POD      FAR      ETS      HK       HSS\n')
            statf.write('============================================================================================================================================\n')
            statf.close()  

    ncl_obs_file = '%s_%s_%s' % (obs_file,interp_grid,region)
    nml_file = '%s.nml' % statfile
    main_nml_file= '%s_main.nml' % statfile
    verif_nml_file='%s_verif.nml' % statfile

    print nml_file
   
    for member in members: 
      for forecast_lead in forecast_leads:
          print forecast_lead
          print os.getcwd()
        
          # Use built-in Date/Time modules
          t = datetime(int(Year),int(Month),int(Day),int(valid_time))
          delta_t = timedelta(hours=-int(forecast_lead))
          ff_t = t + delta_t
        
          ff_file = '%s_mem%04d_%s%02d%02d%02dz+%s' % (model,int(member),ff_t.year,ff_t.month,ff_t.day,ff_t.hour,forecast_lead)
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
              cmd = '%s/cref_interp_hrrre %s model' % (exec_dir,main_nml_file)
              print cmd
              os.system(cmd)

          print interp_grid
                                    
          for threshold in thresholds:
              grid_file = '%s_vs_%s_%sdBZ_%sverif_grids.nc' %  (obs_file,ff_file,threshold,interp_grid)
              ncl_verif_file = '%s_vs_%s_%sdBZverif_%s' % (obs_file,ff_file,threshold,interp_grid)
              
              print grid_file

              nml = open(verif_nml_file,'w')
              nml.write("&verif_hrrre_nml" + '\n')
              nml.write("   threshold = %s " % (threshold) + '\n')
              nml.write("   verif_out_file = '%s.nc' " % (ncl_verif_file) + '\n')
    #          for (sfile,sfileo) in zip(sfiles,sfileos):
    #                  nml.write("   %s = '%s' " % (sfileo,sfile) + '\n')
              nml.write("   %s = '%s' " % (sfileos[int(member)-1],sfiles[int(member)-1]) + '\n')
              nml.write("/" + '\n')
              nml.close()

              os.system('cat %s %s > %s' % (main_nml_file,verif_nml_file,nml_file))
              
              print "NCL_MODEL_FILE: ", ncl_model_file, ".nc"
              print "OBS_FILE: ", obs_dir, "/", valid_dir, "/", ncl_obs_file
              
              if(os.path.isfile('%s.nc' % ncl_model_file) and os.path.isfile('%s/%s/%s.nc' % (obs_dir,valid_dir,ncl_obs_file))):
                  # Write Forecast Lead and Threshold into output statistics files
                 # for sfile in sfiles:
                 #         statf = open(sfile,'a')
                 #         statf.write('   %s         %s   ' % (forecast_lead,threshold))
                 #         statf.close()
                  statf = open(sfiles[int(member)-1],'a')
                  statf.write('   %s         %s   ' % (forecast_lead,threshold))
                  statf.close()

                  # Call do_verif to do verification grid and statistics
                  cmd = '%s/do_verif_hrrre %s' % (exec_dir,nml_file)
                  print cmd
                  os.system(cmd)
                        
                  if(threshold == thresholds[0]):
                      # Call NCL program to create model graphic
                      cmd = """ncl 'INFILENAME="%s.nc"' 'MODEL="%s"' 'FIELDNAME="model"' 'OUTFILENAME="%s"' %s/plot_cref.ncl""" % (ncl_model_file,ncl_model,ncl_model_file,script_dir)
                      print cmd
                      os.system(cmd)
                      #os.system("mv %s.000001.png %s.png" % (ncl_model_file,ncl_model_file))
                      os.system("convert -trim +repage %s.png %s.png" % (ncl_model_file,ncl_model_file))
                      os.system("convert -bordercolor black -border 15x15 %s.png %s.png" % (ncl_model_file,ncl_model_file))
                      os.system("convert -quality 90 -depth 8 %s.png %s.png" % (ncl_model_file,ncl_model_file))
                    
                  # Call NCL program to create verif graphic
                  cmd = """ncl 'INFILENAME="%s.nc"' 'MODEL="%s"' 'FIELDNAME="verif"' 'OUTFILENAME="%s"' %s/plot_cref.ncl""" % (ncl_verif_file,ncl_model,ncl_verif_file,script_dir)
                  print cmd
                  os.system(cmd)
                  #os.system("mv %s.000001.png %s.png" % (ncl_verif_file,ncl_verif_file))
                  os.system("convert -trim +repage %s.png %s.png" % (ncl_verif_file,ncl_verif_file))
                  os.system("convert -bordercolor black -border 15x15 %s.png %s.png" % (ncl_verif_file,ncl_verif_file))
                  os.system("convert -quality 90 -depth 8 %s.png %s.png" % (ncl_verif_file,ncl_verif_file))
                
              else:
                  print 'Either obs file or model file is missing to do verification'

                  # Write Forecast Lead and Threshold into output statistics files
                  #for sfile in sfiles:
                  #        statf = open(sfile,'a')
                  #        statf.write('   %s         %s       -999       -999       -999       -999   |  -999     -999     -999     -999     -999     -999     -999\n' % (forecast_lead,threshold))
                  #        statf.close()
                  statf = open(sfiles[int(member)-1],'a')
                  statf.write('   %s         %s       -999       -999       -999       -999   |  -999     -999     -999     -999     -999     -999     -999\n' % (forecast_lead,threshold))
                  statf.close()
                
#              os.system("rm %s.nc" % ncl_verif_file)
#    os.system('rm *.nml')
    os.chdir('..')


#----------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
