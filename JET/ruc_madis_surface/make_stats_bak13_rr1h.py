#!/usr/bin/python

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




os.environ["DBI_USER"] = "wcron0_user"
os.environ["DBI_PASS"] = "cohen_lee"
os.environ["DBI_DSN"] = "DBI:mysql:madis3:wolphin"

connection = MySQLdb.connect("wolphin",user="wcron0_user",passwd="cohen_lee",db="madis3")
cursor = connection.cursor()


query = """
create table ruc-rr1h-7days
select ruc.net,ruc.N_sites as ruc_N_sites,rr.N_sites as rr_N_sites,
 ruc.min_time,ruc.max_time,ruc.N_T as ruc_N_T,rr.N_T as rr_N_T,
ruc.avg_T as ruc_avg_T,rr.avg_T as rr_avg_T, ruc.avg_T-rr.avg_T as diff_avg_T
 from Bak13_net_7day as ruc,RR1h_net_7day as rr
 where ruc.net = rr.net
 and ruc.min_time = rr.min_time
 and ruc.max_time = rr.max_time
 group by ruc.net
 order by null
"""
print query
cursor.execute(query)



print "NORMAL TERMINATION"

