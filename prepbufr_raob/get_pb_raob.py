#!/usr/bin/python
import sys
import os
from string import *
import time
import re
import math
import operator
try:
    from StringIO import StringIO  # Python 2.7
except ImportError:
    from io import StringIO  # Python 3.x
import gzip

try:
    site = sys.argv[1]
except:
    print("usage: get_pb_raob.py <wmoid> <calsecs> [<model (default: RAOB)>]")
    sys.exit(0)
calsecs = int(sys.argv[2])
try:
    model = sys.argv[3]
except:
    model = "RAOB"

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

tstruct = time.gmtime(calsecs)
dt_str = "{}-{m:02d}-{d:02d} {h:02d}:00:00".\
           format(tstruct.tm_year,m=tstruct.tm_mon,d=tstruct.tm_mday,h=tstruct.tm_hour)

query = """select site,s,time from {model}_raob_soundings
where 1=1
#and fcst_len = 0
and site = '{s}'
and time = '{dt}'
order by time
""".format(s=site,dt=dt_str,model=model)
print(query)
cursor.execute(query)
results = cursor.fetchall()
for row in results:
    site = row[0]
    gzipped_sounding = row[1]
    time = row[2]
    sio = StringIO(gzipped_sounding)
    with gzip.GzipFile(fileobj=sio, mode="r") as f:
        for line in f.read().splitlines():
            print(line)
 