#!/usr/bin/env python

import sys
import os
from string import *
import MySQLdb

# conect to database
try:
    connection = MySQLdb.connect("wolphin.fsl.noaa.gov",
                                 user="surfrad_loader",passwd="isis",
                                 #db="surfrad3")
                                 db="surfrad3",local_infile=True)
except MySQLdb.Error, e:
    print "Error %d: %s" % (e.args[0], e.args[1])
    sys.exit (1)
cursor = connection.cursor()

processed = False
models = {}
# find 'done files'
all_files = os.listdir("tmp/")
for each_file in all_files:
  if each_file.find(".written3") > 0:
      item = each_file.split(".")
      pid = item[0]
      run_time = int(item[1])
      model = item[2]
      fcst_len = int(item[3])
      models[model] = 1
      each_file = "tmp/"+each_file
      if model == 'HRRR':
          n = cursor.execute('SHOW TABLES LIKE "%s"' % model)
          if (n == 0):
             cmd = 'CREATE TABLE %s LIKE template_HRRR' % (model)
             print cmd
             cursor.execute(cmd)
          query = """load data concurrent local infile '%s'
                  replace into table %s columns terminated by ','
                  (id,secs,fcst_len,scale,dswrf,dswrf15,direct,direct15,diffuse,diffuse15) """ % \
              (each_file,model)
      else:
          n = cursor.execute('SHOW TABLES LIKE "%s"' % model)
          if (n == 0):
             cmd = 'CREATE TABLE %s LIKE template' % (model)
             print cmd
             cursor.execute(cmd)
          query = """load data concurrent local infile '%s'
                  replace into table %s columns terminated by ','
                  (id,secs,fcst_len,scale,dswrf)""" % (each_file,model)
          
      print query
      try:
         cursor.execute(query)
      except:
         print("Trouble loading file... possible that it doesn't exist anymore")
      loaded_file = each_file.replace(".written3",".loaded3");
      try:
         os.rename(each_file,loaded_file);
         processed = True
      except:
         print("Trouble renaming file... possible tha tit doesn't exist anymore")


     
