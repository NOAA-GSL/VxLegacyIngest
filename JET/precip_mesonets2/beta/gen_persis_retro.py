#!/usr/bin/python

import sys
import os
from string import *
import MySQLdb
import MySQLdb.cursors

# local modules
from make_subregion_sums_persis import *

# conect to database
try:
    connection = MySQLdb.connect("wolphin.fsl.noaa.gov",
                                 user="wcron0_user",passwd="cohen_lee",
                                 db="precip_mesonets2",local_infile=True,
                                 cursorclass=MySQLdb.cursors.DictCursor)
except MySQLdb.Error, e:
    print "Error %d: %s" % (e.args[0], e.args[1])
    sys.exit (1)
connection.get_warnings = True
cursor = connection.cursor()

# STOP THIS AFTER 1H, SO IT QUITS IN AN ORGANIZED WAY
max_time = 3600
start_secs = time.time()

accum = 1

fcst_lens = [1,2,3,4,5,6,7,8,9,10,11,12]

valid_time1 = 1577239200 # Wed 25 Dec 2019 02:00:00 (day 359, week 2607)
valid_times = [valid_time1 + i*3600 for i in range(0,1000)]

for valid_time in valid_times:
     print "gen new valid time locations"
     query = "drop table if exists loc_tmp"
     cursor.execute(query)
     last_valid_time = valid_time
     query="""\
create temporary table loc_tmp (
`madis_id` mediumint(8) unsigned NOT NULL primary key COMMENT 'id from madis3 database',
`first_time` int(10) unsigned NOT NULL COMMENT 'time this location was first seen for this station',
`reg` set('ALL_RUC','E_RUC','W_RUC','ALL_HRRR','E_HRRR','W_HRRR','ALL_RR1','ALL_RR2','AK','HWT','STMAS_CI',\
         'Global','NHX','SHX','TRO','NHX_E','NHX_W','C','S','SE','N','NE','HI',\
         'AQPI_LARGE','AQPI_HI','AQPI_LO','AQPI_SIERRA') DEFAULT 'Global'
)
select madis_id,first_time,reg
from locations2 loc
where first_time =
  (select first_time from locations2 loc2
  where loc2.first_time <= %s and loc2.madis_id = loc.madis_id
  order by first_time desc limit 1)
""" % (valid_time)
     print query
     cursor.execute(query)
     print cursor.rowcount,"rows affected"
     make_subregion_sums_persis(cursor,valid_time,fcst_lens,accum)
     valid_str = time.strftime("%a, %d %b %Y %H:%M:%S %Z", time.gmtime(valid_time))
     tot_secs = time.time()-start_secs
     print "persistence tables filled for {valid_str}. Took {tot_secs:.0f} secs".\
         format(valid_str=valid_str,tot_secs=tot_secs)
sys.exit(0) 

     
