#!/usr/bin/python

import sys
import os
from string import *
import MySQLdb

# conect to database
try:
    connection = MySQLdb.connect("wolphin.fsl.noaa.gov",
                                 user="ptype_loader",passwd="isis",
                                 db="ptype2",local_infile=True,)
except MySQLdb.Error, e:
    print "Error %d: %s" % (e.args[0], e.args[1])
    sys.exit (1)
cursor = connection.cursor()

processed = False
models = {}
# find 'done files'
all_files = os.listdir("tmp")
for each_file in all_files:
  if each_file.find(".2written") > 0:
      item = each_file.split(".")
      pid = item[0]
      valid_time = int(item[1])
      model = item[2]
      fcst_len = int(item[3])
      each_file = "tmp/"+each_file
      query = """load data concurrent local infile '%s'
                  replace into table %s columns terminated by ','
                  (id,secs,fcst_len,scale,crain,cfrzr,cicep,csnow)""" % \
          (each_file,model)
      print query
      cursor.execute(query)
      loaded_file = each_file.replace(".2written",".loaded");
      os.rename(each_file,loaded_file);
      processed = True


     
