#!/usr/bin/python

import MySQLdb
import sys
from time import gmtime,strftime
from calendar import timegm
import smtplib
from  subprocess import Popen,PIPE
import StringIO

try:
    conn = MySQLdb.connect (read_default_file="~/.my.cnf",
                            db='anomaly_corr_stats')
except MySQLdb.Error, e:
    print "Error %d: %s" % (e.args[0], e.args[1])
    sys.exit (1)

cursor = conn.cursor()

models = ('FIMDC','FIMZDC')
min_run_time = 1282089600               # Wed 18 Aug 2010 00:00:00
max_run_time = {}
max_run_time['FIMDC'] = 1282089600+1
max_run_time['FIMZDC'] = 1282089600

for model in models:
  print "model is %s" % (model)
  for run_time in range(min_run_time,max_run_time[model],12*3600):
    for fcst_len in range(0,168,12):
      valid_time = run_time+fcst_len*3600
      valid_hour = (valid_time % (24*3600))/3600
      valid_day = valid_time - 3600*valid_hour
      run_str = strftime("%Y-%m-%d %H:%M:%S", gmtime(run_time))
      valid_day_str = strftime("%Y-%m-%d", gmtime(valid_day))
      query ="""
delete from stats
where 1=1
and model = '%s'
and valid_date = '%s'
and valid_hour = %s
and fcst_len = %s
""" %\
      (model,valid_day_str,valid_hour,fcst_len)
      #print query
      cursor.execute(query)
      #row = cursor.fetchone()
      #cursor.close()
      print "model %s run %s fcst_len %s valid %s %sZ, count %s " %\
            (model,run_str,fcst_len,valid_day_str,valid_hour,cursor.rowcount)
