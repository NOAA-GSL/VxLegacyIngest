#!/usr/bin/python

import sys
import os
from string import *
import MySQLdb
import MySQLdb.cursors

# local modules
from make_3h_subregion_sums import *

start_secs = time.time()

hrs_ago = abs(int(sys.argv[1]))
print("processing 3h valid time <= %s hours ago"%(hrs_ago))
valid_time = time.time() -  hrs_ago*3600
# put on a 3 hour boundary
valid_time -= valid_time % (3*3600)
valid_time = int(valid_time)
valid_str = time.strftime("%a, %d %b %Y %H:%M:%S %Z", time.gmtime(valid_time))
print("valid_time is %s (%s)"%(valid_str,valid_time))

models_str = sys.argv[2]
models = models_str.split(',')
for model in models:
    print(model)

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

#make 3h ob table
ob_table = "precip_mesonets2.3h_pcp2_{valid_time}".format(valid_time=valid_time)
query="drop table if exists "+ob_table
print(query)
cursor.execute(query)
query="""\
create temporary  table {ob_table} (
  `madis_id` mediumint(8) unsigned NOT NULL COMMENT 'madis_id from madis3 db',
  `valid_time` int(10) unsigned NOT NULL COMMENT 'Valid time, end of ***3h*** accumulation',
  `bilin_pcp_3h` int(10) unsigned DEFAULT NULL COMMENT 'estimated pcp in THREE hours in hundredths of an inch',
  UNIQUE KEY `time_id` (`valid_time`,`madis_id`),
  UNIQUE KEY `id_time` (`madis_id`,`valid_time`)
)  
select o1.madis_id,o1.valid_time
,o1.bilin_pcp+o2.bilin_pcp+o3.bilin_pcp as bilin_pcp_3h
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

if rows == 0:
      print("NO OB DATA FOR THIS VALID TIME -- SKIPPING\n")
else:
  for model in models:
    query="""\
    select fcst_lens from fcst_lens_per_model
    where model = '%s'
    """ % (model)
    print query
    cursor.execute(query)
    fcst_lens_all = cursor.fetchone()['fcst_lens'].split(',')
    #print(fcst_lens_all)
    fcst_lens=[3,9,15]
    #for fcst_len in fcst_lens_all:
      #  if int(fcst_len) % 3 == 0:
        #    fcst_lens.append(fcst_len)
    #fcst_lens=[3]
    print("fcst_lens: %s"%(fcst_lens))
    for fcst_len in fcst_lens:
        #print(fcst_len)
        make_3h_subregion_sums(cursor,model,valid_time,fcst_len,ob_table)
       

 

    
