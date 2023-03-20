#!/usr/bin/env python
#=====================================================================================
# This script will populate all the MySQL tables for the composite reflectivity database
#
# By: Patrick Hofmann
# Last Update: 14 FEB 2011
#
# To execute: ./pop_precip_sql_tables.py
#
#-------------------------------------------------------------------------------------

import MySQLdb
import os
import sys
import calendar
from datetime import datetime
from datetime import timedelta

def main():
    Year         = os.getenv("YEAR")
    Month        = os.getenv("MONTH")
    Day          = os.getenv("DAY")
    Hour         = os.getenv("HOUR")

    rt_dir       = os.getenv("REALTIMEDIR")

    # Set variables
    models     = ['HRRR_devvCPC','RR_devvCPC','RUC_devvCPC']
    sql_models = ['HRRR_dev','RR_dev','RUC_dev']
    grids      = ['03km','13km','20km','40km','80km']

    domains = ['conus','east','west']
    sql_domains = ['CONUS','EUS','WUS']
    
    try:
        db = MySQLdb.connect(host="wolphin.fsl.noaa.gov", user="ejames", passwd="RckSpg", db="precip")
        cursor = db.cursor()
    except MySQLdb.Error, e:
        print "Error %d: %s" % (e.args[0], e.args[1])
        sys.exit (1)

    # Use built-in Date/Time modules
    t = datetime(int(Year),int(Month),int(Day),int(Hour))

    # Database stores time as seconds since 1/1/1970 - UNIX time
    x = t.timetuple()
    sql_t = calendar.timegm(x)
    
    for [sql_model,model] in zip(sql_models,models):
        for grid in grids:
            for (domain,sql_domain) in zip(domains,sql_domains):
                file = '%s/%s/realtime/%4d%02d%02d-%02dz/%sLC/verif_%s_%s_statistics.txt' % \
                       (rt_dir,model,t.year,t.month,t.day,t.hour,grid,grid,domain)
                print file
                
                if (not os.path.isfile(file)):
                    continue
                
                f = open(file,'r')
                
                count = len(f.readlines())
                if count != 26:
                    f.close()
                    continue
                
                # Read header lines
                f.seek(0)
                f.readline()
                f.readline()
                
                # Loop over statistics
                for line in f:
                    a = line.split()
                    if (a[2] == '-999'):
                        continue
                    
                    num_f = 24/int(a[0])  #Number of forecasts (2 or 8)
                    trsh  = a[1]          #Threshold (0.01-3.00)
                    yy    = a[2]          #Hit
                    yn    = a[3]          #Miss
                    ny    = a[4]          #False Alarm
                    nn    = a[5]          #Correct Rejection
                    
                    sql_table = '%s_%s_%s' % (sql_model,grid,sql_domain)
                    
                    cmd = 'REPLACE INTO %s VALUES(%s,%s,%s,%s,%s,%s,%s)' % (sql_table,sql_t,num_f,trsh,yy,yn,ny,nn)
                    
                    cursor.execute(cmd)
                f.close()
                    
    cursor.close()
    db.close()

#-----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
