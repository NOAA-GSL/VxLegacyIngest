#!/usr/bin/python

import sys
import os
from string import *
import MySQLdb
import MySQLdb.cursors

# local modules
from make_subregion_sums import *

def by_valid_time(filename):
     if filename.find(".written") > 0:
         item=filename.split(".")
         #print filename
         sort_key = int(item[1]) + int(item[3])/100.
         #print 'key is',sort_key
         return sort_key
     else:
         return 1e20

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

last_valid_time=0;
# find 'written' files
all_files = os.listdir("tmp")
all_files.sort(key=by_valid_time)
#print all_files
for each_file in all_files:
   now_secs = time.time()
   if now_secs - start_secs > max_time:
          sys.exit(0)
   #print each_file
   if each_file.find(".written") > 0 and each_file.find("_data") > 0:
     item = each_file.split(".")
     pid = item[0]
     valid_time = int(item[1])
     model = item[2]
     fcst_len = int(item[3])
     accum = int(item[4][4])
     each_file = "tmp/"+each_file
     if valid_time != last_valid_time:
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

         # create 3h sums for GFS (although GFS isn't available every hour!
         ob_table = "precip_mesonets2.3h_pcp2_{valid_time}".format(valid_time=valid_time)
         query="drop table if exists "+ob_table
         print(query)
         cursor.execute(query)
         query="""\
create temporary  table {ob_table} (
  `madis_id` mediumint(8) unsigned NOT NULL COMMENT 'madis_id from madis3 db',
  `valid_time` int(10) unsigned NOT NULL COMMENT 'Valid time, end of ***3h*** accumulation',
  `bilin_pcp` int(10) unsigned DEFAULT NULL COMMENT 'estimated pcp in THREE hours in hundredths of an inch',
  UNIQUE KEY `time_id` (`valid_time`,`madis_id`),
  UNIQUE KEY `id_time` (`madis_id`,`valid_time`)
)  
select o1.madis_id,o1.valid_time
,o1.bilin_pcp+o2.bilin_pcp+o3.bilin_pcp as bilin_pcp
from
hourly_pcp2 o1,hourly_pcp2 o2, hourly_pcp2 o3
where 1=1
and o1.madis_id = o2.madis_id
and o1.madis_id = o3.madis_id
and o2.valid_time = o1.valid_time - 1*3600
and o3.valid_time = o1.valid_time - 2*3600
and o1.valid_time = {valid_time}
""".format(ob_table=ob_table,valid_time=valid_time)
         print(query)
         rows=cursor.execute(query)
         print("%s rows affected"%(rows))
        

     try:
        if model.find("NAVGEM") >= 0:
            query = """load data concurrent local infile '%s'
                  replace into table %s columns terminated by ','
                  (madis_id,valid_time,fcst_len,precip_accum)""" % (each_file,model)
        else:
            query = """load data concurrent local infile '%s'
                  replace into table %s columns terminated by ','
                  (madis_id,valid_time,fcst_len,precip)""" % (each_file,model)
        print(each_file)
        print(query)
        if (not os.path.isfile(each_file)):
           print("%s file does not exist" % each_file)
           continue
        else:
           try:
              cursor.execute(query)
           except:
              print("Trouble loading the file. It may not exist anymore.")
           loaded_file = each_file.replace(".written",".loaded")
           try:
              os.rename(each_file,loaded_file)
           except:
              print("Trouble renaming the file. It may not exist anymore.")
           make_subregion_sums(cursor,model,valid_time,fcst_len,accum)
     except MySQLdb.Error, e:
        print "Error %d: %s" % (e.args[0], e.args[1])
        sys.exit(1)
        
sys.exit(0) 

     
