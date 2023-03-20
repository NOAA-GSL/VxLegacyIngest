#!/usr/bin/python

import sys
import os
from string import *
import MySQLdb

# conect to database
try:
    connection = MySQLdb.connect("wolphin.fsl.noaa.gov",
                                 user="surfrad_loader",passwd="isis",
                                 db="surfrad",local_infile=True)
except MySQLdb.Error, e:
    print "Error %d: %s" % (e.args[0], e.args[1])
    sys.exit (1)
cursor = connection.cursor()

processed = False
models = {}
# find 'done files'
all_files = os.listdir("tmp/")
for each_file in all_files:
  if each_file.find(".written") > 0:
      item = each_file.split(".")
      pid = item[0]
      run_time = int(item[1])
      model = item[2]
      fcst_len = int(item[3])
      models[model] = 1
      each_file = "tmp/"+each_file
      if model == "HRRR" or model == "WRF_solar" or model == "HRRR_OPS":
          query = """load data concurrent local infile '%s'
                  replace into table %s columns terminated by ','
                  (id,secs,fcst_len,dswrf3,dswrf13,dswrf20,dswrf40)""" % (each_file,model)
      else:
          query = """load data concurrent local infile '%s'
                  replace into table %s columns terminated by ','
                  (id,secs,fcst_len,dswrf13,dswrf20,dswrf40)""" % (each_file,model)
      print query
      cursor.execute(query)
      loaded_file = each_file.replace(".written",".loaded");
      os.rename(each_file,loaded_file);
      processed = True


     
