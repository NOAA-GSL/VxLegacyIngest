#!/usr/bin/env python
#=====================================================================================
# This script will run verif_iplib to create output verification grids and statistics.
#
# By: Patrick Hofmann
# Last Update: 22 JUN 2010
#
# To execute: ./combine_3km_files.py
#
#-------------------------------------start-------------------------------------------
import sys
import os

def main():
    # Get environment variables
    Year        = os.getenv("YEAR")
    Month       = os.getenv("MONTH")
    Day         = os.getenv("DAY")
    Hour        = os.getenv("HOUR")

    rt_dir      = os.getenv("REALTIMEDIR")
    
    interp_grid = os.getenv("INTERPGRID")
    statfile    = os.getenv("STATF")

    domains = ['conus','west','east']

    #-----------------------------End of Definitions------------------------------------

    # Make new dir for this Forecast validialization
    valid_dir = '%s%s%s-%sz' % (Year,Month,Day,Hour)
    os.chdir('%s' % rt_dir)

    for domain in domains:
        
        cmd = 'cat %s/%s/%s_A_%s_statistics.txt > %s/%s/%s_%s_statistics.txt' % \
              (valid_dir,interp_grid,statfile,domain,valid_dir,interp_grid,statfile,domain)
        print cmd
        os.system(cmd)
        
        cmd = 'tail -n +3 %s/%s/%s_B_%s_statistics.txt >> %s/%s/%s_%s_statistics.txt' % \
              (valid_dir,interp_grid,statfile,domain,valid_dir,interp_grid,statfile,domain)
        print cmd
        os.system(cmd)
        
        cmd = 'tail -n +3 %s/%s/%s_C_%s_statistics.txt >> %s/%s/%s_%s_statistics.txt' % \
              (valid_dir,interp_grid,statfile,domain,valid_dir,interp_grid,statfile,domain)
        print cmd
        os.system(cmd)
    
        cmd = 'tail -n +3 %s/%s/%s_D_%s_statistics.txt >> %s/%s/%s_%s_statistics.txt' % \
              (valid_dir,interp_grid,statfile,domain,valid_dir,interp_grid,statfile,domain)
        print cmd
        os.system(cmd)

#----------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
