#!/usr/bin/python

import sys
import os
from string import *
import MySQLdb
import MySQLdb.cursors

# conect to database
try:
    connection = MySQLdb.connect("wolphin.fsl.noaa.gov",
                                 user="wcron0_user",passwd="cohen_lee",
                                 db="precip_mesonets2_sums")
except MySQLdb.Error, e:
    print "Error %d: %s" % (e.args[0], e.args[1])
    sys.exit (1)
connection.get_warnings = True
cursor = connection.cursor()

model = "HRRR_OPS"
query = 'show tables like "{model}%"'.format(model=model)
print query
cursor.execute(query)
tables = cursor.fetchall();
for table in tables:
    old_table = table[0]
    #print old_table
    if old_table.find("_3h") > 0:
        continue
    new_table = old_table.replace(model,"HRRR_OPS_old")
    query = 'create table '+new_table+' like '+old_table
    #query = 'delete from '+new_table
    print query
    cursor.execute(query)
 
