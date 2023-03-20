#!/usr/bin/env python
#============================================================================================
# This script will create output verification grids and statistics for
#     (CCFP,RCPF,HCPF,LLProb) vs. NSSL
#
# By: Patrick Hofmann
# Last Update: 28 SEP 2013
#
# To execute: ./Prob_NSSL_verif.py
#
#-------------------------------------start-------------------------------------------------
import sys
import os
import resource
from datetime import datetime
from datetime import timedelta

def main():
    # Get environment variables
    Year        = os.getenv("YEAR")
    Month       = os.getenv("MONTH")
    Day         = os.getenv("DAY")
    valid_time  = os.getenv("HOUR")

    exec_dir    = os.getenv("EXECDIR")
    script_dir  = os.getenv("SCRIPTDIR")
    rt_dir      = os.getenv("REALTIMEDIR")
    obs_dir     = os.getenv("OBSDIR")
    model_dir   = os.getenv("MODELDIR")
    
    statfile    = os.getenv("STATFILE")
    obs_file    = os.getenv("OBSFILE")
    
    interp_grid = os.getenv("INTERPGRID")
    res         = os.getenv("GRID")

    nc_out_var  = os.getenv("NCOUTVAR")
    model       = os.getenv("MODEL")
    ncl_model   = os.getenv("NCLMODEL")
    
    thresholds     = (os.getenv("THRESHOLDS")).split()
    forecast_leads = (os.getenv("FORECASTLEADS")).split()
    
    # Select subdomains for statistical calculations
    do_conus = True
    do_west  = True
    do_east  = True
    do_ne    = True
    do_se    = True
    #-----------------------------End of Definitions-----------------------------------

    resource.setrlimit(resource.RLIMIT_STACK,(1600000000,1600000000))
    
    # Make new dir for this verification grid
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,valid_time)
    print valid_dir
    if(os.path.isdir('%s/%s/%s' % (rt_dir,valid_dir,interp_grid))):
        os.chdir('%s/%s/%s' % (rt_dir,valid_dir,interp_grid))
    else:
        os.system('mkdir -p %s/%s/%s' % (rt_dir,valid_dir,interp_grid))
        os.chdir('%s/%s/%s' % (rt_dir,valid_dir,interp_grid))
    
    # Create subdomain files
    postpend = 'statistics.txt'
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

    ncl_obs_file = 'nssl_mosaic_%s' % interp_grid

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
        ff_file = '%s_%sz+%02d' % (model,ff_time,int(forecast_lead))
        ncl_model_file = '%s' % ff_file

        # Write namelist
        nml = open(main_nml_file,'w')
        nml.write("&main_nml" + '\n')
        nml.write("   model_out_file = '%s/%s/%s/%s.nc' " % (model_dir,ff_dir,interp_grid,ncl_model_file) + '\n')
        nml.write("   obs_out_file = '%s/%s/%s.nc' " % (obs_dir,valid_dir,ncl_obs_file) + '\n')
        nml.write("   nc_out_var = '%s' " % (nc_out_var) + '\n')
        nml.write("   valid_time = '%s%s%s%s' " % (Year,Month,Day,valid_time) + '\n')
        nml.write("   initial_time = '%s' " % (ff_time) + '\n')
        nml.write("   forecast_time = '%02d' " % (int(forecast_lead)) + '\n')
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
            for (bool,boolstr,sfile,sfileo) in zip(bools,boolstrs,sfiles,sfileos):
                if(bool):
                    nml.write("   %s = .true. " % boolstr + '\n')
                    nml.write("   %s = '%s' " % (sfileo,sfile) + '\n')
            nml.write("/" + '\n')
            nml.close()

            os.system('cat %s %s > %s' % (main_nml_file,verif_nml_file,nml_file))

            print '%s/%s/%s/%s.nc' % (model_dir,ff_dir,interp_grid,ncl_model_file)
            print '%s/%s/%s.nc' % (obs_dir,valid_dir,ncl_obs_file)
            if(os.path.isfile('%s/%s/%s/%s.nc' % (model_dir,ff_dir,interp_grid,ncl_model_file)) and os.path.isfile('%s/%s/%s.nc' % (obs_dir,valid_dir,ncl_obs_file))):
                # Write Forecast Lead and Threshold into output statistics files
                for (bool,sfile) in zip(bools,sfiles):
                    if(bool):
                        statf = open(sfile,'a')
                        statf.write('   %s         %s   ' % (forecast_lead,threshold))
                        statf.close()
                # Call do_verif to do verification grid and statistics
                cmd = '%s/do_verif %s' % (exec_dir,nml_file)
                print cmd
                os.system(cmd)
                if (not os.path.isfile('%s.nc' % ncl_verif_file)):
                    for (bool,sfile) in zip(bools,sfiles):
                        if(bool):
                            statf = open(sfile,'a')
                            statf.write('    -999       -999       -999       -999   |  -999     -999     -999     -999     -999     -999     -999\n')
                            statf.close()
                    continue

                # Call NCL program to create verif graphic
                if (threshold == '0.25' or threshold == '0.40' or threshold == '0.75'):
                    cmd = """ncl 'INFILENAME="%s.nc"' 'MODEL="%s"' 'FIELDNAME="verif"' 'NCVAR="%s"' 'TITLEVAR="Convective Coverage"' 'RES="%s"' 'OUTFILENAME="%s"' %s/plot_prob.ncl""" % (ncl_verif_file,ncl_model,nc_out_var,res,ncl_verif_file,script_dir)
                    print cmd
                    os.system(cmd)
                    os.system("mv %s.000001.png %s.png" % (ncl_verif_file,ncl_verif_file))
                    os.system("convert -trim +repage %s.png %s.png" % (ncl_verif_file,ncl_verif_file))
                    os.system("convert -bordercolor black -border 15x15 %s.png %s.png" % (ncl_verif_file,ncl_verif_file))
                    os.system("convert -quality 90 -depth 8 %s.png %s.png" % (ncl_verif_file,ncl_verif_file))
                    
                if(model == 'ccfp'):
                    # Call special NCL script to plot CCFP and NCWD, with stats
                    ccfpf = '%s/%s/%s/%s.nc' % (model_dir,ff_dir,interp_grid,ncl_model_file)
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
            else:
                print 'Either obs file or model file is missing to do verification'

                # Write Forecast Lead and Threshold into output statistics files
                for (bool,sfile) in zip(bools,sfiles):
                    if(bool):
                        statf = open(sfile,'a')
                        statf.write('   %s         %s       -999       -999       -999       -999   |  -999     -999     -999     -999     -999     -999     -999\n' % (forecast_lead,threshold))
                        statf.close()

            os.system("rm %s.nc" % ncl_verif_file)
    #os.system('rm *.nml')
    os.chdir('..')


#----------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
