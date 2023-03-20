#!/usr/bin/python

import sys
import os
from string import *
import MySQLdb
import MySQLdb.cursors
import time

# conect to database
try:
    connection = MySQLdb.connect("wolphin.fsl.noaa.gov",
                                 user="wcron0_user",passwd="cohen_lee",
                                 db="precip_mesonets2",
                                 cursorclass=MySQLdb.cursors.DictCursor)
except MySQLdb.Error, e:
    print "Error %d: %s" % (e.args[0], e.args[1])
    sys.exit (1)
connection.get_warnings = True
cursor = connection.cursor()

valid_times=[]

hrs_ago = 0
if len(sys.argv) > 1 and abs(int(sys.argv[1])) > 0:
    hrs_ago = abs(int(sys.argv[1]))
    print "processing",hrs_ago,"hours ago"
    valid_time = time.time() -  hrs_ago*3600
   # put on an hour boundary
    valid_time -= valid_time % 3600
    valid_times.append(valid_time)
else:
    # no arg was input. Use latest valid_time from hourly_pcp2
    query="select max(valid_time) as vt from hourly_pcp2"
    print query
    cursor.execute(query)
    row = cursor.fetchone()
    valid_time =row['vt']
    print 'valid_time',valid_time
    valid_times.append(valid_time)

# for retro
valid_times = [1548460800]  # Sat 26 Jan 2019 00:00:00 (day 26, week 2560)

# also, see if we have needed valid times
all_files = os.listdir("tmp")
for each_file in all_files:
    if each_file.find("need") > -1:
        print "each file: ",each_file
        item = each_file.split(".")
        valid_time = int(item[1])
        valid_times.append(valid_time)
        os.remove("tmp/"+each_file)
                  
for valid_time in valid_times:
   valid_str = time.strftime("%a, %d %b %Y %H:%M:%S %Z", time.gmtime(valid_time))
   print "loading stations for ",valid_str
   query="""\
select s.madis_id,lat/100 as lat,lon/100 as lon,elev
from pcp_stations2 s, locations2 loc
where 1=1
and s.madis_id = loc.madis_id
and loc.first_time =
(select first_time
from locations2 loc where first_time <= %s and loc.madis_id = s.madis_id
order by first_time desc limit 1)
order by s.madis_id
   """ % (valid_time)

   print query
   f = open("tmp/pcp_mesonet_stations."+str(int(valid_time))+".txt","w")
   cursor.execute(query)
   n_rows=0
   for row in cursor.fetchall():
      #print('{madis_id} {lat:.2f} {lon:.2f} {elev}'.format(**row))
      f.write('{madis_id} {lat:.2f} {lon:.2f} {elev}\n'.format(**row))
      n_rows = n_rows+1

print n_rows,"rows written"
connection.close();
f.close

