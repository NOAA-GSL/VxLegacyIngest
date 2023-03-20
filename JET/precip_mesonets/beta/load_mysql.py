#!/usr/bin/python

import sys
import os
from string import *
import MySQLdb

# local modules
from make_subregion_sums import *

# conect to database
try:
    connection = MySQLdb.connect("wolphin.fsl.noaa.gov",
                                 user="wcron0_user",passwd="cohen_lee",
                                 db="precip_mesonets")
except MySQLdb.Error, e:
    print "Error %d: %s" % (e.args[0], e.args[1])
    sys.exit (1)
connection.get_warnings = True
cursor = connection.cursor()

# find 'done files'
all_files = os.listdir("tmp")
for each_file in all_files:
    if each_file.find(".written") > 0 and each_file.find(".PCP_1h_data") > 0:
        item = each_file.split(".")
        pid = item[0]
        valid_time = int(item[1])
        model = item[2]
        fcst_len = int(item[3])
        each_file = "tmp/"+each_file
        if model.find("NAVGEM") >= 0:
            query = """load data concurrent local infile '%s'
                  replace into table %s columns terminated by ','
                  (madis_id,valid_time,fcst_len,precip_accum)""" % (each_file,model)
        else:
            query = """load data concurrent local infile '%s'
                  replace into table %s columns terminated by ','
                  (madis_id,valid_time,fcst_len,precip)""" % (each_file,model)
        print query
        cursor.execute(query)
        loaded_file = each_file.replace(".written",".loaded")
        os.rename(each_file,loaded_file)
        
        make_subregion_sums(cursor,model,valid_time,fcst_len);
 

     
