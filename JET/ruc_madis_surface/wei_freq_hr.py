#!/usr/bin/py
# to run : python surface_driver.py 0
import os
import sys
import MySQLdb
import sys
from time import gmtime,strftime
from calendar import timegm
import smtplib
from  subprocess import Popen,PIPE
import StringIO
from string import *
import random
import datetime
import time
import math
import re
import zlib
import get_iso_file3
import get_grid
import update_summaries3

fcst_len=[1,3,6,9,12]
mytime = 1386028800 # 2013 12 03 00 

hrs_back=[0,1,3,8]
count={}
for hh in range(0,23*30):

 for hrs in hrs_back:
  
  valid_time = mytime + hh* 3600 - hrs*3600
  for each_fcst in fcst_len:

      valid_str = time.ctime(valid_time)
      run_time = valid_time - each_fcst*3600
      run_str = time.ctime(run_time)
      run_yymmdd= datetime.datetime.fromtimestamp(run_time)
      fname = "%4d"%run_yymmdd.year+"%02d"%run_yymmdd.month+"%02d"%run_yymmdd.day+"%02d"%run_yymmdd.hour +"%02d"%each_fcst
      if fname in count.keys():
         count[fname]= count[fname] + 1 
      else:
         count[fname]= 0
         count[fname]= count[fname] + 1 

#      print "fcst at "+str(each_fcst)+"hr "+"%4d"%run_yymmdd.year+"%02d"%run_yymmdd.month+"%02d"%run_yymmdd.day+"%02d"%run_yymmdd.hour +"%02d"%each_fcst
#      sys.exit(0)
#      print  "valid at "+str(valid_str)+ " run from " +str(run_str)+" for "+str(each_fcst)+" hr fcst"

#  print "###############"

print count

for each in count.keys():
  print each, count[each]
