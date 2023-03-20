#!/usr/bin/env python

import sys
import os
import time
from string import *
import MySQLdb
import MySQLdb.cursors

def by_run_time(filename):
     if filename.find(".written") > 0:
         item=filename.split(".")
         #print filename
         sort_key = int(item[0]) 
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

last_run_time=0;
# find 'written' files
all_files = os.listdir("tmp")
all_files.sort(key=by_run_time)
#print all_files
for each_file in all_files:
   now_secs = time.time()
   if now_secs - start_secs > max_time:
          sys.exit(0)
   #print each_file
   if each_file.find(".written") > 0 and each_file.find("_data") > 0:
     item = each_file.split(".")
     run_time = int(item[0])
     model = item[1]
     fcst_len = int(item[2])
     accum = int(item[3][2])
     pid = item[4]
     each_file = "tmp/"+each_file

     try:
        if model.find("NAVGEM") >= 0:
            query = """load data concurrent local infile '%s'
                  replace into table %s columns terminated by ','
                  (madis_id,run_time,fcst_len,precip_accum)""" % (each_file,model)
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
     except MySQLdb.Error, e:
        print "Error %d: %s" % (e.args[0], e.args[1])
        sys.exit(1)
        
sys.exit(0) 

     
