#!/usr/bin/env python
#=====================================================================================
# This script will populate all the MySQL tables for the composite reflectivity database
#
# By: Patrick Hofmann
# Last Update: 13 JUN 2012
#
# To execute: ./pop_etp_sql_tables.py
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
    models       = (os.getenv("MODELNAMES")).split()
    modelfiles   = (os.getenv("MODELDIRS")).split()
    grids        = (os.getenv("GRIDS")).split()
    n            = int(os.getenv("LINES"))
    
    trshs   = ['25','30','35','40','45']
    domains = ['ne','se','conus','east','west']
    sql_domains = ['NE','SE','CONUS','EUS','WUS']
    
    try:
        db = MySQLdb.connect(host="wolphin.fsl.noaa.gov", user="ejames", passwd="RckSpg", db="echotop")
        cursor = db.cursor()
    except MySQLdb.Error, e:
        print "Error %d: %s" % (e.args[0], e.args[1])
        sys.exit (1)

    # Use built-in Date/Time modules
    t = datetime(int(Year),int(Month),int(Day),int(Hour))

    # Database stores time as seconds since 1/1/1970 - UNIX time
    x = t.timetuple()
    sql_t = calendar.timegm(x)

    for (model,modelfile) in zip(models,modelfiles):
        for grid in grids:
            if (grid == '03kmLC' and model != 'HRRR'):
                continue
            
            for (domain,sql_domain) in zip(domains,sql_domains):
                file = '%s/%s/%4d%02d%02d-%02dz/%sLC/verif_%s_%s_statistics.txt' % \
                       (rt_dir,modelfile,t.year,t.month,t.day,t.hour,grid,grid,domain)
                print file
                
                if (not os.path.isfile(file)):
                    continue

                sql_table = '%s_%s_%s' % (model,grid,sql_domain)

                # Check if table exists; create if necessary
                m = cursor.execute('SHOW TABLES LIKE "%s"' % sql_table)
                if (m == 0):
                    cmd = 'CREATE TABLE %s_%s_%s LIKE template' % (model,grid,sql_domain)
                    print cmd
                    cursor.execute(cmd)

                f = open(file,'r')
                
                count = len(f.readlines())
                #if count != n:
                #    f.close()
                #    continue
                
                # Read header lines
                f.seek(0)
                f.readline()
                f.readline()
                
                # Loop over statistics
                for line in f:
                    a = line.split()
                    if (a[2] == '-999'):
                        continue
                    
                    f_len = a[0]
                    trsh  = a[1]
                    yy    = a[2]  #Hit
                    yn    = a[3]  #Miss
                    ny    = a[4]  #False Alarm
                    nn    = a[5]  #Correct Rejection

                    # Fill table
                    cmd = 'REPLACE INTO %s VALUES(%s,%s,%s,%s,%s,%s,%s)' % (sql_table,sql_t,f_len,trsh,yy,yn,ny,nn)
                    cursor.execute(cmd)
                f.close()
                    
    cursor.close()
    db.close()

#-----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
