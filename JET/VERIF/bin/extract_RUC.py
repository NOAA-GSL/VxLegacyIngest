#!/usr/bin/env python
#======================================================================================
# This script will first untar and then move RUC files into their respective valid time
# directories, with appropriate names and fields saved.
#
# By: Patrick Hofmann
# Last Update: 04 OCT 2010
#
#---------------------------------------start-------------------------------------------
import sys
import os
import resource
from datetime import datetime
from datetime import timedelta
from datetime import date

def main():

    Year = '2010'
    Months = ['%02d' % x for x in range(6,8)]
    Days   = ['%02d' % x for x in range(1,32)]
    Hours  = ['%02d' % x for x in range(0,24)]

    forecast_leads = ['%02d' % x for x in range(0,16)]
    
    rt_dir = '/pan1/projects/nrtrr/verif/cref/RUC/realtime'

    cref_var = ':REFC:'
    pcp_var1 = ':NCPCP:'
    pcp_var2 = ':ACPCP:'
    
    #-----------------------------End of Definitions--------------------------------

    # First, set stacksize to 512MB
    resource.setrlimit(resource.RLIMIT_STACK,(1600000000,1600000000))

    for Month in Months:
        for Day in Days:
            if (Day == '31'):
                continue
            for Hour in Hours:
                # Construct valid dir under run dir
                valid_dir = '%s%s%s-%sz' % (Year,Month,Day,Hour)
                print valid_dir
                os.chdir(rt_dir)
                os.system('mkdir %s' % valid_dir)
                
                for forecast_lead in forecast_leads:
                    print forecast_lead
                    # Use built-in Date/Time modules
                    t = datetime(int(Year),int(Month),int(Day),int(Hour))
                    delta_t = timedelta(hours=-int(forecast_lead))
                    ff_t = t + delta_t
                    
                    # Have to get fancy with dates, since RR wants day # of year
                    rr_ff = ff_t.strftime('%y%j%H')

                    # Get model data
                    forecast_file = '%s0000%s' % (rr_ff,forecast_lead)
                    print forecast_file
                    new_file = 'ruc_%4d%02d%02d%02dz+%s' % (ff_t.year,ff_t.month,ff_t.day,ff_t.hour,forecast_lead)
                    
                    if (os.path.isfile('%s' % (forecast_file))):
                        # Ungrib RR file into NetCDF, remove grib2 file
                        cmd = 'wgrib2 %s | egrep "(%s|%ssurface:%d-%d hour acc fcst:|%ssurface:%d-%d hour acc fcst:)" | wgrib2 -i %s -netcdf %s.nc' %  \
                              (forecast_file,cref_var,pcp_var1,int(forecast_lead)-1,int(forecast_lead),pcp_var2,int(forecast_lead)-1,int(forecast_lead),forecast_file,new_file)
                        print cmd
                        os.system(cmd)
                        os.system('mv %s.nc %s/' % (new_file,valid_dir))
                        #os.remove('%s' % forecast_file)
                    else:
                        print 'RR forecast missing'

#----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
