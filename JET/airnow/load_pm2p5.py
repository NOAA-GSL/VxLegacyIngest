#!/usr/bin/python

import sys
import os
from string import *
import MySQLdb
import MySQLdb.cursors
# local modules
from make_subregion_sums import *

# conect to database
try:
    connection = MySQLdb.connect("wolphin.fsl.noaa.gov",
                                 user="wcron0_user",passwd="cohen_lee",
                                 db="airnow",local_infile=True,
                                cursorclass=MySQLdb.cursors.DictCursor)
except MySQLdb.Error, e:
    print "Error %d: %s" % (e.args[0], e.args[1])
    sys.exit (1)
cursor = connection.cursor()

processed = False
models = {}
# find 'done files'
all_files = os.listdir("tmp")
for each_file in all_files:
  if each_file.endswith("written3"):
    try:
      item = each_file.split(".")
      pid = item[0]
      run_time = int(item[1])
      model = item[2]
      fcst_len = int(item[3])
      models[model] = 1
      each_file = "tmp/"+each_file
      query = """load data concurrent local infile '%s'
                  replace into table %s columns terminated by ','
                  (id,time,fcst_len,scale,pm2p5_10) """ % \
              (each_file,model)
           
      print query
      cursor.execute(query)
      valid_time = run_time + 3600*fcst_len
      make_subregion_sums(cursor,model,valid_time,fcst_len)
      
      loaded_file = each_file.replace(".written3",".loaded3");
      os.rename(each_file,loaded_file);
      processed = True
    except Exception as e:
        print(type(e))
        print(e.args)
        print(e)
        pass

sys.exit(0)


     
