#!/usr/bin/python
import sys
import os
from string import *
import time
import re
import math
import operator
from gen_regions import gen_regions
try:
    from StringIO import StringIO  # Python 2.7
except ImportError:
    from io import StringIO  # Python 3.x
import gzip

import MySQLdb
# conect to database
try:
    connection = MySQLdb.connect("wolphin.fsl.noaa.gov",
                                 user="surfrad_loader",passwd="isis",
                                 db="soundings_pb",local_infile=True)
except MySQLdb.Error as e:
    print("Error {}: {}|".format(e.args[0], e.args[1]))
    sys.exit (1)
cursor = connection.cursor()

# Look at data from past 30 days
query = """select site,s,time from soundings_pb.RAOB_raob_soundings
where 1=1
and fcst_len =0
and time > date_sub(now(), interval 30 day)
order by time
"""
print(query)
cursor.execute(query)
results = cursor.fetchall()
lat_pb ={}
lon_pb = {}
elev_pb = {}
name_pb = {}
time_pb={}
moving_pb={}
diff_metadata_pb={}
first_time_pb={}
last_time_pb={}
lat_m ={}
lon_m={}
elev_m={}
name_m={}
descript_m={}
regions_m={}
first_time=""
last_time=""
max_dist=10
for row in results:
    gzipped_sounding = row[1]
    time = row[2]
    last_time = time
    if first_time =="":
        first_time = time

    #print(site)
    sio = StringIO(gzipped_sounding)
    with gzip.GzipFile(fileobj=sio, mode="r") as f:
        for line in f.read().splitlines():
            #print(line)
            sounding_line = line.split()
            if sounding_line[0] == '1':
                #print(line)
                wmoid = line[14:21].lstrip().lstrip("0") # IS A STRING
                if not first_time_pb.has_key(wmoid):
                    first_time_pb[wmoid]=time
                try:
                    if time > last_time_pb[wmoid]:
                        last_time_pb[wmoid]=time
                except KeyError:
                    last_time_pb[wmoid]=time
                #print(wmoid)
                stuff = line[22:].split()
                #print(line[14:])
                latlon = stuff[0]
                # check number of dots (lat and lon may be merged together
                n_dots = len(latlon.split('.'))-1
                if n_dots == 1:
                    # lat and lon have a space between them
                    lat = float(latlon[:-1])
                    ns = latlon[-1:]
                    if ns == 'S':
                        lat = -lat
                    lon_str = stuff[1]
                    elev = int(stuff[2])
                else:
                    #lat and lon are merged
                    stuff2 = re.split('N|S',latlon)
                    lat = float(stuff2[0])
                    ns = latlon[len(stuff2[0]):len(stuff2[0])+1]
                    if ns == 'S':
                        lat = -lat
                    #print("{} {} {}".format(latlon,lat,ns))
                    lon_str = stuff2[1]
                    elev = int(stuff[1])
                lon = float(lon_str[:-1])
                ew = lon_str[-1:]
                if ew == 'W':
                    lon = -lon
                #print("{} {} {} {} {}".format(wmoid,site,lat,lon,elev))
                # check that the location may have changed
                if lat_pb.has_key(wmoid):
                    if lat_pb[wmoid] != lat or \
                       lon_pb[wmoid] != lon or \
                       elev_pb[wmoid] != elev:
                        print "TROUBLE. Apparently moving station. Removing from further consideration:"
                        print("{} {} {} {} {} {}".\
                              format(wmoid,lat_pb[wmoid],lon_pb[wmoid],elev_pb[wmoid],time_pb[wmoid],name_pb[wmoid]))
                        print("{} {} {} {} {}".format(wmoid,lat,lon,elev,time))
                        lat_pb.pop(wmoid)
                        moving_pb[wmoid]=time
                if not moving_pb.has_key(wmoid):
                     lat_pb[wmoid]=lat
                     lon_pb[wmoid]=lon
                     elev_pb[wmoid]=elev
                     time_pb[wmoid]=time
            elif sounding_line[0] == '3':
                name = sounding_line[1]
                #print("name for {} is {}".format(wmoid,name))
                name_pb[wmoid]=name
    #print(wmoid,time)               
# now check the existing metadata (from Mark's RAOBs)
query ="""
select wmoid,name,lat,lon,elev,descript
from ruc_ua.metadata
order by wmoid
"""
print(query)
cursor.execute(query)
results = cursor.fetchall()
i=0;
for s in results:
        #print(s)
        i += 1
        #print("{} {} {} {} {}".format(s[0],s[1],s[2],s[3],s[4]))
        wmoid = str(s[0])
        name_m[wmoid]=s[1]
        lat_m[wmoid]=float(s[2])/100
        lon_m[wmoid]=float(s[3])/100
        elev_m[wmoid]=int(s[4])
        descript_m[wmoid] = s[5]
        #print("{} {} {}".format(lat_m[wmoid],lon_m[wmoid],elev_m[wmoid]))
        if s[5] != None:
            descript_m[wmoid].replace('!','|')  # '!' is used to separate columns in the mysql load data statement below
            
print("{} stations read in from ruc_ua.metadata".format(i))

new_pb_stations=0
tot_pb_stations=0
different_pb_stations=0
way_different_pb_stations=0
for wmoid in sorted(lat_pb.keys()):
    tot_pb_stations +=1
    #print("{} {} {} {} {}".format(wmoid,name_pb[wmoid],lat_pb[wmoid],lon_pb[wmoid],elev_pb[wmoid]))
    if name_m.has_key(wmoid):
        #print("checking metadata file for {}".format(wmoid))
        if lat_m[wmoid] != lat_pb[wmoid] or \
            lon_m[wmoid] != lon_pb[wmoid] or \
            abs(elev_m[wmoid] - elev_pb[wmoid]) > 5 or \
            name_m[wmoid] != name_pb[wmoid]:
            if wmoid.__eq__('x70414'):
                print "TROUBLE! prepBUFR site differs from metadata data:"
                print("prep_BUFR: {} {} {} {} {}".\
                      format(wmoid,name_pb[wmoid],lat_pb[wmoid],lon_pb[wmoid],elev_pb[wmoid]))
                print(" metadata: {} {} {} {} {}".\
                      format(wmoid,name_m[wmoid],lat_m[wmoid],lon_m[wmoid],elev_m[wmoid]))
            different_pb_stations += 1
            dlon = lon_m[wmoid] - lon_pb[wmoid]
            if dlon > 180:
                dlon -= 360
            if dlon < -180:
                dlon += 360
            dlat = lat_m[wmoid] - lat_pb[wmoid]
            dist = math.sqrt(dlat**2 + (math.cos(lat_m[wmoid]/57.2958)*dlon)**2)*60*1.852 #in km
            if wmoid.__eq__('x70414'):
                print "distance is {}, dlon = {}, dlat = {}".format(dist,dlon,dlat)
            if dist > max_dist:
                #print("prep_BUFR: {} {} {} {} {}".\
                    #format(wmoid,name_pb[wmoid],lat_pb[wmoid],lon_pb[wmoid],elev_pb[wmoid]))
                #print(" metadata: {} {} {} {} {} {}".\
                  #    format(wmoid,name_m[wmoid],lat_m[wmoid],lon_m[wmoid],elev_m[wmoid],descript_m[wmoid]))
                diff_metadata_pb[wmoid]=dist
                way_different_pb_stations += 1
        else:
            #print("NEW wmoid |{}| in prepBUFR (above)".format(wmoid))
            new_pb_stations = new_pb_stations+1

print("List of stations with loc differences between prepBUFR and old ruc_ua.metadata of more than {} km:".\
      format(max_dist))
by_distance = sorted(diff_metadata_pb.items(), key=operator.itemgetter(1),reverse=True)
for item in by_distance:
    wmoid = item[0]
    print("{:.1f} <- distance from old loc. {} {} New/old loc: {}/{} {}/{} {}/{} {}".\
          format(diff_metadata_pb[wmoid],wmoid,name_pb[wmoid],\
                 lat_pb[wmoid],lat_m[wmoid],lon_pb[wmoid],lon_m[wmoid],\
                 elev_pb[wmoid],elev_m[wmoid],descript_m[wmoid]))

# remove non-numerical wmoid's
for wmoid in sorted(lat_pb.keys()):
     if not wmoid.isdigit():
         print("removing non-digit wmoid {}".format(wmoid))
         lat_pb.pop(wmoid)
         
print("{} new reporting stations from prepBUFR".format(new_pb_stations))     
print("{} reporting stations from prepBUFR with different locations than in metadata, of which".\
      format(different_pb_stations))     
print("{} reporting stations from prepBUFR were more than {} km from their metadata locations".\
      format(way_different_pb_stations,max_dist))     
print("{} total reporting stations from prepBUFR (not including {} moving stations)".\
      format(tot_pb_stations,len(moving_pb)))     
print("between {} and {}".format(first_time,last_time))               

# update 'metadata table'
mysql_load_file = "tmp/mysql_input.{}.tmp".format(os.getpid())
fout = open(mysql_load_file,'w')
for wmoid in sorted(lat_pb.keys(),key=int):
          regions = gen_regions(wmoid,name_pb[wmoid],lat_pb[wmoid],lon_pb[wmoid])
          try:
              descript = descript_m[wmoid]
              if descript == "NULL":
                  descript = "\\N";
          except KeyError:
              descript = "\\N"
          fout.write("{}!{}!{}!{}!{}!{}!{}!{}\n".\
                     format(wmoid,name_pb[wmoid],lat_pb[wmoid]*100,lon_pb[wmoid]*100,elev_pb[wmoid],\
                            regions,descript,last_time_pb[wmoid]))
fout.close()
query="""
load data local infile '{}'
replace into table ruc_ua_pb.metadata
fields terminated by '!'
(wmoid,name,lat,lon,elev,reg,descript,latest)""".format(mysql_load_file)
#print("query is {}".format(query))
cursor.execute(query)
#os.remove(mysql_load_file)

# update the 'moving' table
moving_load_file = "tmp/moving_input.{}.tmp".format(os.getpid())
fout = open(moving_load_file,'w')
for wmoid in sorted(moving_pb.keys()):
    fout.write("{}!{}\n".format(wmoid,moving_pb[wmoid]))
fout.close()    
query="""
load data local infile '{}'
replace into table ruc_ua_pb.moving
fields terminated by '!'
(wmoid,latest)""".format(moving_load_file)
#print("query is {}".format(query))
cursor.execute(query)
os.remove(moving_load_file)

    
 
