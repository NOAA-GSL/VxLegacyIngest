#!/usr/bin/python

import sys
import os
from string import *
import MySQLdb
import MySQLdb.cursors

# local modules
from make_subregion_sums import *

def by_valid_time(filename):
     if filename.find(".PCP_1h_data") > 0:
         item=filename.split(".")
         #print filename
         sort_key = int(item[1]) + int(item[3])/100.
         #print 'key is',sort_key
         return sort_key
     else:
         return 1e20

cursor = dict(
      All= '1',
      RAWS='2',
      HadsRaws='3',
      MesoWest='4')
 
# conect to database
try:
    connection = MySQLdb.connect("wolphin.fsl.noaa.gov",
                                 user="wcron0_user",passwd="cohen_lee",
                                 db="precip_mesonets2",local_infile=True,
                                 cursorclass=MySQLdb.cursors.DictCursor)
    connection1 = MySQLdb.connect("wolphin.fsl.noaa.gov",
                                 user="wcron0_user",passwd="cohen_lee",
                                 db="precip_mesonets2",local_infile=True,
                                 cursorclass=MySQLdb.cursors.DictCursor)
    connection2 = MySQLdb.connect("wolphin.fsl.noaa.gov",
                                 user="wcron0_user",passwd="cohen_lee",
                                 db="precip_mesonets2",local_infile=True,
                                 cursorclass=MySQLdb.cursors.DictCursor)
    connection3 = MySQLdb.connect("wolphin.fsl.noaa.gov",
                                 user="wcron0_user",passwd="cohen_lee",
                                 db="precip_mesonets2",local_infile=True,
                                 cursorclass=MySQLdb.cursors.DictCursor)
except MySQLdb.Error, e:
    print "Error %d: %s" % (e.args[0], e.args[1])
    sys.exit (1)
connection.get_warnings = True
cursor['All'] = connection.cursor()
cursor['RAWS'] = connection.cursor()
cursor['HadsRaws'] = connection.cursor()
cursor['MesoWest'] = connection.cursor()

last_valid_time=0;
# find 'written' files
all_files = os.listdir("tmp2")
all_files.sort(key=by_valid_time)
#print all_files
for each_file in all_files:
    #print each_file
    if each_file.find(".written") > 0 and each_file.find(".PCP_1h_data") > 0:
     item = each_file.split(".")
     pid = item[0]
     valid_time = int(item[1])
     model = item[2]
     fcst_len = int(item[3])
     each_file = "tmp2/"+each_file
     if valid_time != last_valid_time:
         print "gen new valid time locations"
         query = "drop table if exists loc_tmp"
         cursor['All'].execute(query)
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
         cursor['All'].execute(query)
         print cursor['All'].rowcount,"rows affected"
         
     try:
        if model.find("NAVGEM") >= 0:
            query = """load data concurrent local infile '%s'
                  replace into table %s columns terminated by ','
                  (madis_id,valid_time,fcst_len,precip_accum)""" % (each_file,model)
        else:
            query = """load data concurrent local infile '%s'
                  replace into table %s columns terminated by ','
                  (madis_id,valid_time,fcst_len,precip)""" % (each_file,model)
        print query
        cursor['All'].execute(query)
        #loaded_file = each_file.replace(".written",".loaded")
        #os.rename(each_file,loaded_file)
        print "here!"
        make_subregion_sums(cursor['All'],model,valid_time,fcst_len)
     except:
        pass
    sys.exit(0)
        
sys.exit(0) 

     
