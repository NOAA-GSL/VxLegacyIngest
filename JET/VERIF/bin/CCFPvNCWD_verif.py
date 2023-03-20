#!/usr/bin/env python
#======================================================================================
# This script will create output verification grids and statistics for CCFP vs. NCWD
#
# By: Patrick Hofmann
# Last Update: 08 APR 2011
#
# To execute: ./CCFPvNCWD_verif.py
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
    statfile   = os.getenv("STATF")
    
    # Looping variables
    thresholds     = ['0.25','0.40','0.75']
    forecast_leads = ['02','04','06'] 

    # Static variables
    ncl_dir = '/opt/ncl/5.2.0_bin'
    nc_out_var = 'coverage'
    obs_file = 'ncwd_04km'
    model = 'ccfp'
    ncl_model = 'CCFP'
    interp_grid = 'ncwd_04km'
    
    # Select subdomains for statistical calculations
    do_conus = True
    do_west  = True
    do_east  = True
    do_ne    = True
    do_se    = True
    #-----------------------------End of Definitions-----------------------------------
    
    # Set environment variable to fix NCL 5.2 bug
    os.putenv("UDUNITS2_XML_PATH",'%s/lib/ncarg/udunits/udunits2.xml' % ncl_dir)

    # Make new dir for this verification grid
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,valid_time)
    print valid_dir
    if(os.path.isdir('%s/%s/%s' % (rt_dir,valid_dir,interp_grid))):
        os.chdir('%s/%s/%s' % (rt_dir,valid_dir,interp_grid))
    else:
        os.system('mkdir -p %s/%s/%s' % (rt_dir,valid_dir,interp_grid))
        os.chdir('%s/%s/%s' % (rt_dir,valid_dir,interp_grid))
    
    # open statistics files and add Headers
    if(do_conus):
        c_ascii_file = '%s_conus_statistics.txt' % (statfile)
        statf = open(c_ascii_file,'w')
        statf.write('LeadTime   Threshold    Hits      Misses      FAs       CNs        Bias     CSI      POD      FAR      ETS      HK       HSS\n')
        statf.write('============================================================================================================================================\n')
        statf.close()
    if(do_west):
        w_ascii_file = '%s_west_statistics.txt' % (statfile)
        statf = open(w_ascii_file,'w')
        statf.write('LeadTime   Threshold    Hits      Misses      FAs       CNs        Bias     CSI      POD      FAR      ETS      HK       HSS\n')
        statf.write('============================================================================================================================================\n')
        statf.close()
    if(do_east):
        e_ascii_file = '%s_east_statistics.txt' % (statfile)
        statf = open(e_ascii_file,'w')
        statf.write('LeadTime   Threshold    Hits      Misses      FAs       CNs        Bias     CSI      POD      FAR      ETS      HK       HSS\n')
        statf.write('============================================================================================================================================\n')
        statf.close()
    if(do_ne):
        ne_ascii_file = '%s_ne_statistics.txt' % (statfile)
        statf = open(ne_ascii_file,'w')
        statf.write('LeadTime   Threshold    Hits      Misses      FAs       CNs        Bias     CSI      POD      FAR      ETS      HK       HSS\n')
        statf.write('============================================================================================================================================\n')
        statf.close()
    if(do_se):
        se_ascii_file = '%s_se_statistics.txt' % (statfile)
        statf = open(se_ascii_file,'w')
        statf.write('LeadTime   Threshold    Hits      Misses      FAs       CNs        Bias     CSI      POD      FAR      ETS      HK       HSS\n')
        statf.write('============================================================================================================================================\n')
        statf.close()

    ncl_obs_file = '%s' % (obs_file,interp_grid)

    nml_file = '%s.nml' % statfile
    main_nml_file= '%s_main.nml' % statfile
    verif_nml_file='%s_verif.nml' % statfile

    t = datetime(int(Year),int(Month),int(Day),int(valid_time))
    
    for forecast_lead in forecast_leads:
        print forecast_lead
        print os.getcwd()
        
        # Use built-in Date/Time modules
        delta_t = timedelta(hours=-int(forecast_lead))
        ff_t = t + delta_t

        ff_time = '%04d%02d%02d%02d' % (ff_t.year,ff_t.month,ff_t.day,ff_t.hour)
        ff_dir  = '%04d%02d%02d-%02dz' % (ff_t.year,ff_t.month,ff_t.day,ff_t.hour)
        ff_file = '%s_%sz+%s' % (model,ff_time,forecast_lead)
        ncl_model_file = '%s' % ff_file

        # Write namelist
        nml = open(main_nml_file,'w')
        nml.write("&main_nml" + '\n')
        nml.write("   model_out_file = '%s/%s/%s.nc' " % (model_dir,ff_dir,ncl_model_file) + '\n')
        nml.write("   obs_out_file = '%s/%s/%s.nc' " % (obs_dir,valid_dir,ncl_obs_file) + '\n')
        nml.write("   nc_out_var = '%s' " % (nc_out_var) + '\n')
        nml.write("   valid_time = '%s%s%s%s' " % (Year,Month,Day,valid_time) + '\n')
        nml.write("   initial_time = '%s' " % (ff_time) + '\n')
        nml.write("   forecast_time = '%s' " % (forecast_lead) + '\n')
        nml.write("   interp_grid = '%s' " % (interp_grid) + '\n')
        nml.write("/" + '\n')
        nml.close()

        print '../%s.nc' % ff_file
        print '%s/%s.nc' % (obs_dir,ncl_obs_file)
        print interp_grid
                                    
        for threshold in thresholds:
            ncl_verif_file = '%s_vs_%s_%2d%%_verif_%s' % (obs_file,ff_file,float(threshold)*100,interp_grid)
            
            nml = open(verif_nml_file,'w')
            nml.write("&verif_nml" + '\n')
            nml.write("   threshold = %s " % (threshold) + '\n')
            nml.write("   verif_out_file = '%s.nc' " % (ncl_verif_file) + '\n')
            if(do_conus):
                nml.write("   conus_out_file = '%s' " % (c_ascii_file) + '\n')
            else:
                nml.write("   do_conus = .false.")
            if(do_west):
                nml.write("   west_out_file = '%s' " % (w_ascii_file) + '\n')
            else:
                nml.write("   do_west = .false.")
            if(do_east):
                nml.write("   east_out_file = '%s' " % (e_ascii_file) + '\n')
            else:
                nml.write("   do_east = .false.")
            if(do_ne):
                nml.write("   ne_out_file = '%s' " % (ne_ascii_file) + '\n')
            else:
                nml.write("   do_ne = .false.")   
            if(do_se):
                nml.write("   se_out_file = '%s' " % (se_ascii_file) + '\n')
            else:
                nml.write("   do_se = .false.")
            nml.write("/" + '\n')
            nml.close()

            os.system('cat %s %s > %s' % (main_nml_file,verif_nml_file,nml_file))

            print '%s/%s/%s.nc' % (model_dir,ff_dir,ncl_model_file)
            print '%s/%s/%s.nc' % (obs_dir,valid_dir,ncl_obs_file)
            if(os.path.isfile('%s/%s/%s.nc' % (model_dir,ff_dir,ncl_model_file)) and os.path.isfile('%s/%s/%s.nc' % (obs_dir,valid_dir,ncl_obs_file))):
                # Write Forecast Lead and Threshold into output statistics files
                if(do_conus):
                    statf = open(c_ascii_file,'a')
                    statf.write('   %s         %s   ' % (forecast_lead,threshold))
                    statf.close()
                if(do_west):
                    statf = open(w_ascii_file,'a')
                    statf.write('   %s         %s   ' % (forecast_lead,threshold))
                    statf.close()
                if(do_east):
                    statf = open(e_ascii_file,'a')
                    statf.write('   %s         %s   ' % (forecast_lead,threshold))
                    statf.close()
                if(do_ne):
                    statf = open(ne_ascii_file,'a')
                    statf.write('   %s         %s   ' % (forecast_lead,threshold))
                    statf.close()
                if(do_se):
                    statf = open(se_ascii_file,'a')
                    statf.write('   %s         %s   ' % (forecast_lead,threshold))
                    statf.close()
                
                # Call do_verif to do verification grid and statistics
                cmd = '%s/do_verif %s' % (exec_dir,nml_file)
                print cmd
                os.system(cmd)
                        
                # Call NCL program to create verif graphic
                cmd = """ncl 'INFILENAME="%s.nc"' 'MODEL="%s"' 'FIELDNAME="verif"' 'NCVAR="%s"' 'TITLEVAR="Convective Coverage"' 'OUTFILENAME="%s"' %s/plot_prob.ncl""" % (ncl_verif_file,ncl_model,nc_out_var,ncl_verif_file,script_dir)
                print cmd
                os.system(cmd)
                os.system("mv %s.000001.png %s.png" % (ncl_verif_file,ncl_verif_file))
                os.system("convert -trim +repage %s.png %s.png" % (ncl_verif_file,ncl_verif_file))
                os.system("convert -bordercolor black -border 15x15 %s.png %s.png" % (ncl_verif_file,ncl_verif_file))
                os.system("convert -quality 90 -depth 8 %s.png %s.png" % (ncl_verif_file,ncl_verif_file))
                
            else:
                print 'Either obs file or model file is missing to do verification'

                # Write Forecast Lead and Threshold into output statistics files
                if(do_conus):
                    statf = open(c_ascii_file,'a')
                    statf.write('   %s         %s       -999       -999       -999       -999   |  -999     -999     -999     -999     -999     -999     -999\n' % (forecast_lead,threshold))
                    statf.close()
                if(do_west):
                    statf = open(w_ascii_file,'a')
                    statf.write('   %s         %s       -999       -999       -999       -999   |  -999     -999     -999     -999     -999     -999     -999\n' % (forecast_lead,threshold))
                    statf.close()
                if(do_east):
                    statf = open(e_ascii_file,'a')
                    statf.write('   %s         %s       -999       -999       -999       -999   |  -999     -999     -999     -999     -999     -999     -999\n' % (forecast_lead,threshold))
                    statf.close()
                if(do_ne):
                    statf = open(ne_ascii_file,'a')
                    statf.write('   %s         %s       -999       -999       -999       -999   |  -999     -999     -999     -999     -999     -999     -999\n' % (forecast_lead,threshold))
                    statf.close()
                if(do_se):
                    statf = open(se_ascii_file,'a')
                    statf.write('   %s         %s       -999       -999       -999       -999   |  -999     -999     -999     -999     -999     -999     -999\n' % (forecast_lead,threshold))
                    statf.close()

            if(os.path.isfile('%s/%s/%s.nc' % (model_dir,ff_dir,ncl_model_file)) and os.path.isfile('%s/%s/%s.nc' % (obs_dir,valid_dir,ncl_obs_file))):
                # Call special NCL script to plot CCFP and NCWD, with stats
                ccfpf = '%s/%s/%s.nc' % (model_dir,ff_dir,ncl_model_file)
                ncwdf = '%s/%s/%s.nc' % (obs_dir,valid_dir,ncl_obs_file)
                verf1 = '%s_vs_%s_25%%_verif_%s.nc' %  (obs_file,ff_file,interp_grid)
                verf2 = '%s_vs_%s_40%%_verif_%s.nc' %  (obs_file,ff_file,interp_grid)
                mainf = '%s_vs_%s_%s_complete' % (obs_file,ff_file,interp_grid)
                cmd = """ncl 'CCFPFILE="%s"' 'NCWDFILE="%s"' 'VERIFFILE1="%s"' 'VERIFFILE2="%s"' 'OUTFILENAME="%s"' %s/plot_ccfp_ncwd.ncl""" % (ccfpf,ncwdf,verf1,verf2,mainf,script_dir)
                print cmd
                os.system(cmd)
                os.system("mv %s.000001.png %s.png" % (mainf,mainf))
                os.system("convert -trim +repage %s.png %s.png" % (mainf,mainf))
                os.system("convert -bordercolor white -border 15x15 %s.png %s.png" % (mainf,mainf))
                os.system("convert -quality 90 -depth 8 %s.png %s.png" % (mainf,mainf))
                
    os.chdir('..')


#----------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
