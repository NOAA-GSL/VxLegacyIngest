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
    
    models     = (os.getenv("MODELS")).split()
    obs        = (os.getenv("SQLOBS")).split()
    sql_models = (os.getenv("SQLMODELS")).split()
    grids      = (os.getenv("GRIDS")).split()

    #domains = ['conus','east','west','ne','se','northwest']
    #sql_domains = ['CONUS','EUS','WUS','NE','SE','NORTHWEST']
    domains = ['east','ne','se','northwest']
    sql_domains = ['EUS','NE','SE','NORTHWEST']
    
    try:
        db = MySQLdb.connect(host="wolphin.fsl.noaa.gov", user="ejames", passwd="RckSpg", db="precip_new")
        cursor = db.cursor()
    except MySQLdb.Error, e:
        print "Error %d: %s" % (e.args[0], e.args[1])
        sys.exit (1)

    # Use built-in Date/Time modules
    t = datetime(int(Year),int(Month),int(Day),int(Hour))

    # Database stores time as seconds since 1/1/1970 - UNIX time
    x = t.timetuple()
    sql_t = calendar.timegm(x)
    
    for [sql_model,model,analysis] in zip(sql_models,models,obs):
        for grid in grids:
            for (domain,sql_domain) in zip(domains,sql_domains):
                file = '%s/%s/%4d%02d%02d-%02dz/%sLC/verif_%s_%s_precip_statistics.txt' % \
                       (rt_dir,model,t.year,t.month,t.day,t.hour,grid,grid,domain)
                print file
                
                if (not os.path.isfile(file)):
                    print "Doesn't exist!!"
                    continue

                sql_table = '%s_%s_%s_%s' % (sql_model,grid,analysis,sql_domain)
                
                # Check if table exists; create if necessary
                n = cursor.execute('SHOW TABLES LIKE "%s"' % sql_table)
                if (n == 0):
                    cmd = 'CREATE TABLE %s LIKE template' % (sql_table)
                    print cmd
                    cursor.execute(cmd)
                
                f = open(file,'r')
                
                count = len(f.readlines())
                
                # Read header lines
                f.seek(0)
                f.readline()
                f.readline()
                
                # Loop over statistics
                for line in f:
                    a = line.split()
                    if (a[2] == '-999'):
                        continue

                    ff    = int(a[0])  # Forecast length
                    trsh  = a[1]          #Threshold (0.01-3.00)
                    hit    = a[2]          #Hit
                    miss    = a[3]          #Miss
                    fa    = a[4]          #False Alarm
                    cn    = a[5]          #Correct Rejection

                    # Fill table
                    cmd = 'REPLACE INTO %s VALUES(%s,%s,%s,%s,%s,%s,%s)' % (sql_table,sql_t,ff,trsh,hit,miss,fa,cn)
                    print cmd
                    cursor.execute(cmd)
                    
                f.close()
                    
    cursor.close()
    db.close()

#-----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
