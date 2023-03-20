#!/usr/bin/env python
#=====================================================================================
# This script will populate all the MySQL tables for the precip database
#
# By: Patrick Hofmann
# Last Update: 14 NOV 2011
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
    
    lns        = int(os.getenv("LINES"))
    models     = (os.getenv("MODELS")).split()
    sql_models = (os.getenv("SQLMODELS")).split()
    grids      = (os.getenv("GRIDS")).split()

    domains = ['conus','east','west','ne','se','northwest']
    sql_domains = ['CONUS','EUS','WUS','NE','SE','NORTHWEST']
    
    try:
        db = MySQLdb.connect(host="wolphin.fsl.noaa.gov", user="ejames", passwd="RckSpg", db="precip2")
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
                if (model.startswith(('RRFS_dev')) and (grid == "03km")):
                   file = '%s/%s/%4d%02d%02d-%02dz/%sLCrrfs/verif_%s_%s_sub24hr_statistics.txt' % \
                          (rt_dir,model,t.year,t.month,t.day,t.hour,grid,grid,domain)
                else:
                   file = '%s/%s/%4d%02d%02d-%02dz/%sLC/verif_%s_%s_sub24hr_statistics.txt' % \
                       (rt_dir,model,t.year,t.month,t.day,t.hour,grid,grid,domain)
                print file
                
                if (not os.path.isfile(file)):
                    continue

                sql_table = '%s_%s_%s' % (sql_model,grid,sql_domain)
                
                # Check if table exists; create if necessary
                n = cursor.execute('SHOW TABLES LIKE "%s"' % sql_table)
                if (n == 0):
                    cmd = 'CREATE TABLE %s_%s_%s LIKE template' % (sql_model,grid,sql_domain)
                    print cmd
                    cursor.execute(cmd)
                
                f = open(file,'r')
                
                count = len(f.readlines())
              #  if count != lns:
              #      f.close()
              #      continue
                
                # Read header lines
                f.seek(0)
                f.readline()
                f.readline()
                
                # Loop over statistics
                for line in f:
                    a = line.split()
                    if (a[2] == '-999'):
                        continue

                    ff    = int(a[0])     #Accumulation length (6 or 12, currently)
                    trsh  = a[1]          #Threshold (0.01-3.00)
                    yy    = a[2]          #Hit
                    yn    = a[3]          #Miss
                    ny    = a[4]          #False Alarm
                    nn    = a[5]          #Correct Rejection

                    # Fill table
                    cmd = 'REPLACE INTO %s VALUES(%s,%s,%s,%s,%s,%s,%s)' % (sql_table,sql_t,ff,trsh,yy,yn,ny,nn)
                    cursor.execute(cmd)
                    
                f.close()
                    
    cursor.close()
    db.close()

#-----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
