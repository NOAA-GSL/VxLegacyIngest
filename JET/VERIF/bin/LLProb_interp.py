#!/usr/bin/env python
#========================================================================================
# This script will retrieve and process a LLProb NetCDF4 LamAz-grid file into a NetCDF3
# EquiCyl file. 
# These files are NetCDF3, and mapped onto the NCWD grid. The forecasts are then plotted.
#
# By: Patrick Hofmann
# Last Update: 10 MAY 2011
#
# To execute: ./LLProb_interp.py
#
# Example LLProb file: 20110429T171500Z.nc
# Recent files kept on disk at: /public/data/grids/mitll/probfcst/[30,50]
#
#---------------------------------------start--------------------------------------------
import sys
import os
import subprocess
import resource
from datetime import datetime
from datetime import timedelta
from datetime import date

def main():
    Year       = os.getenv("YEAR")
    Month      = os.getenv("MONTH")
    Day        = os.getenv("DAY")
    valid_time = os.getenv("HOUR")
    
    exec_dir   = os.getenv("EXECDIR")
    script_dir = os.getenv("SCRIPTDIR")
    rt_dir     = os.getenv("REALTIMEDIR")
    src_dir    = os.getenv("SRCDIR")

    # Static variables
    titles  = ['MITLL Probability Field - 30% trsh, 4KM','MITLL Probability Field - 30% trsh, 80KM']
    invar   = 'ProbFcst'
    outvar  = 'prob'
    rad_pts = ['2','35']
    interp_grids = ['ncwd_04km','ncwd_80km']
    meths = ['NBAVG','NBMAX']
    
    #-----------------------------End of Definitions--------------------------------
    print resource.getrlimit(resource.RLIMIT_STACK)
    # First, set stacksize to 805MB
    resource.setrlimit(resource.RLIMIT_STACK,(805000000,805000000))
    print resource.getrlimit(resource.RLIMIT_STACK)

    print os.getenv("SRCDIR")
    # Construct valid dir under run dir
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,valid_time)
    print valid_dir

    if (not os.path.isdir('%s/%s' % (rt_dir,valid_dir))):
        os.mkdir('%s/%s' % (rt_dir,valid_dir))
    os.chdir('%s/%s' % (rt_dir,valid_dir))

    print os.getcwd()
    # Copy source LLProb file to directory
    src_file = '%s%s%sT%s0000Z.nc' % (Year,Month,Day,valid_time)
    cmd = 'cp %s/%s .' % (src_dir,src_file)
    print cmd
    os.system(cmd)
    
    t = datetime(int(Year),int(Month),int(Day),int(valid_time))
    init_str = '%4d%02d%02d%02d' % (t.year,t.month,t.day,t.hour)
    
    for (title,grid,rad_pt,meth) in zip(titles,interp_grids,rad_pts,meths):
        if (not os.path.isdir('%s' % grid)):
            os.mkdir('%s' % grid)
        os.chdir('%s' % grid)
        print os.getcwd()
        for ff in range(0,8):
            delta_t = timedelta(hours=ff)
            valid_t = t + delta_t
            valid_str = '%4d%02d%02d%02d' % (valid_t.year,valid_t.month,valid_t.day,valid_t.hour)
            ff_str = '%02d' % ff
            out_file = 'llprob_%4d%02d%02d%02dz+%02d' % (t.year,t.month,t.day,t.hour,ff)
            
            # Interpolate and convert file from LamAz/NetCDF4 to EquiCyl/NetCDF3
            cmd = '%s/lamaz_prob_interp ../%s %s.nc %s %s %s %s %s %s %s %s' % (exec_dir,src_file,out_file,init_str,valid_str,ff_str,invar,outvar,grid,rad_pt,meth)
            print cmd
            os.system(cmd)
            
            # Plot the LLProb Analysis
            if (os.path.isfile('%s.nc' % out_file)):
                
                # Call NCL program to create obs graphic
                cmd = """ncl 'INFILENAME="%s.nc"' 'OUTFILENAME="%s"' 'TITLE="%s"' 'VARNAME="%s"' %s/plot_prob_ll.ncl""" % (out_file,out_file,title,outvar,script_dir)
                print cmd
                os.system(cmd)
                os.system("mv %s.000001.png %s.png" % (out_file,out_file))
                os.system("convert -trim +repage %s.png %s.png" % (out_file,out_file))
                os.system("convert -bordercolor black -border 15x15 %s.png %s.png" % (out_file,out_file))
                os.system("convert -quality 90 -depth 8 %s.png %s.png" % (out_file,out_file))
            else:
                print 'LLProb file missing'

        os.chdir('../')
    #os.system('rm %s' % src_file)

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
