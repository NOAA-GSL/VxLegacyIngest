#!/usr/bin/env python
#=====================================================================================
# This script will populate all the MySQL tables for the composite reflectivity database
#
# By: Patrick Hofmann
# Last Update: 14 FEB 2011
#
# To execute: ./pop_prob_sql_tables.py
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
    models     = ['CCFPvNSSL','LLProbvNSSL','RCPFvNSSL','HCPFvNSSL']
    sql_models = ['CCFP','LLProb','RCPF','HCPF']
    grids      = ['03kmLC']
    sql_grids  = ['03km']
    statfiles  = ['verif_03km']

    domains = ['conus','east','west','ne','se']
    sql_domains = ['CONUS','EUS','WUS','NE','SE']
    
    try:
        db = MySQLdb.connect(host="wolphin.fsl.noaa.gov", user="ejames", passwd="RckSpg", db="prob")
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
        for (sql_grid,grid,statfile) in zip(sql_grids,grids,statfiles):
            for (domain,sql_domain) in zip(domains,sql_domains):
                file = '%s/%s/realtime/%4d%02d%02d-%02dz/%s/%s_%s_statistics.txt' % \
                       (rt_dir,model,t.year,t.month,t.day,t.hour,grid,statfile,domain)
                print file
                
                if (not os.path.isfile(file)):
                    continue

                sql_table = '%s_%s_%s' % (sql_model,sql_grid,sql_domain)

                # Check if table exists; create if necessary
                n = cursor.execute('SHOW TABLES LIKE "%s"' % sql_table)
                if (n == 0):
                    cmd = 'CREATE TABLE %s_%s_%s LIKE template' % (sql_model,sql_grid,sql_domain)
                    print cmd
                    cursor.execute(cmd)
                
                f = open(file,'r')
                
                count = len(f.readlines())
                if (sql_model == 'CCFP'):
                    if (count != 11):
                        f.close()
                        continue
                elif (sql_model == 'LLProb'):
                    if (count != 90):
                        f.close()
                        continue
                else:
                    if (count != 123):
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
                    
                    num_f = a[0]          #Forecast length
                    trsh  = a[1]          #Threshold (0.1,0.2,...,0.90, 0.25, 0.75)
                    yy    = a[2]          #Hit
                    yn    = a[3]          #Miss
                    ny    = a[4]          #False Alarm
                    nn    = a[5]          #Correct Rejection
                    
                    # Fill table
                    cmd = 'REPLACE INTO %s VALUES(%s,%s,%s,%s,%s,%s,%s)' % (sql_table,sql_t,num_f,trsh,yy,yn,ny,nn)
                    cursor.execute(cmd)
                f.close()
                    
    cursor.close()
    db.close()

#-----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
