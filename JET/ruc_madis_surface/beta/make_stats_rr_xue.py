#!/usr/bin/python
# to run this program ./make_stats.py ndays
# ndays in the range [1,7]


#  Set the name of the job.
#$ -N make_stats_rr
#  Make sure that the .e and .o file arrive in the working directory
#$ -cwd
#
#  Set the account
#$ -A wrfruc
#
#  Ask for 1 cpus of type service
#$ -pe service 1
#
#  My code is re-runnable
#$ -r y
#
# send mail on abort, end
#$ -m a
#$ -M Xue.Wei@noaa.gov
#
#  The max walltime 
#$ -l h_rt=01:00:00
#
#$ -e tmp/
#$ -o tmp/
#




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


#model_base= "Bak13"
model_base= "RR1h"

thisDir = os.getenv("SGE_O_WORKDIR")

if os.getenv("SGE_O_WORKDIR"):
   thisDir = os.getenv("SGE_O_WORKDIR")
else:
    basename=sys.argv[0]
    thisDir = "./"



DEBUG=1


os.environ["DBI_USER"] = "wcron0_user"
os.environ["DBI_PASS"] = "cohen_lee"
os.environ["DBI_DSN"] = "DBI:mysql:madis3:wolphin"

connection = MySQLdb.connect("wolphin",user="wcron0_user",passwd="cohen_lee",db="madis3")
cursor = connection.cursor()



#t= datetime.datetime.utcnow()
#last_time = int(time.mktime(t.timetuple()))
last_time = int(time.time()) - 24*3600*2
#last_time =datetime.datetime.now()

dtime=0
print sys.argv[0]
print sys.argv[1]
n_days = int(sys.argv[1])

print "len(sys.argv)",len(sys.argv)

if len(sys.argv)>2:
   back_end_days = sys.argv[2]
else:
    back_end_days = 0 

print "Calculating surface stats for", n_days, "ending=", back_end_days 
print last_time

print thisDir



# get limits from the database
query = "select S_for_DIR_limit from limits"
cursor.execute(query)
# return a tuple, len=1, tuple[0][0] is string
r=cursor.fetchall()

S_for_DIR_limit = int(r[0][0])
print "S_for_DIR_limit",S_for_DIR_limit

#cursor.close()

endSecs = last_time - 7200
endSecs = endSecs - endSecs % 86400; 
endSecs = endSecs - back_end_days*24*3600
startSecs = endSecs - n_days*24*3600

print endSecs, startSecs



table = model_base+"_short"
query = "drop table if exists "+ table
print  query
cursor.execute(query)



query ="""create table """+table+""" select sta_id,time,temp,dp,wd,ws
from """+model_base+"qp1f"+""" # changed from "p1f" by wrm on 17-Oct-2011
where 1=1
and time >= """+str(startSecs) +"""
and time < """+str(endSecs)

print query
cursor.execute(query)
#r=cursor.fetchall()
n_rows = cursor.rowcount



this_time = int(time.time())
dtime = this_time - last_time
print "create table " + table +str(n_rows) +" rows took" +str(dtime)
last_time = this_time

table = model_base+"_net_short"
query = "drop table if exists "+table
cursor.execute(query)

query = """create table """+table+""" 
select net,sta_id,time,temp,dp,wd,ws
from """+model_base+"""_short,stations
where 1=1
and stations.id = """+model_base+"""_short.sta_id
"""

print query
cursor.execute(query)
r=cursor.fetchall()
n_rows = cursor.rowcount
print "n_rows=",n_rows


this_time = int(time.time())
dtime = this_time - last_time
print "create table " + table +str(n_rows) +" rows took" +str(dtime)
last_time = this_time


table = model_base+"_net_"+str(n_days)+"day"
query = "drop table if exists "+table

print  query
cursor.execute(query)

query= """
create table """+table+""" 
(
 net varchar(15) not null,
N_sites int unsigned not null,
min_time int not null,
max_time int not null,
N_T int unsigned not null,
avg_T float,
bias_T float,
std_T float,
N_S int unsigned not null,
avg_S float,
bias_S float,
std_S float,
N_DIR int unsigned,
bias_DIR float,
std_DIR float,
std_W float,
avg_W float,
rms_W float,
N_Td int,
avg_Td float,
bias_Td float,
std_Td float
)
#explain partitions
select net,count(distinct m.sta_id) as N_sites
 ,min(o.time) as min_time,max(o.time) as max_time
 ,count(o.temp) as N_T
 ,avg(o.temp)/10 as avg_T, avg(o.temp-m.temp)/10 as bias_T
 ,std(o.temp-m.temp)/10 as std_T
 ,count(o.ws) as N_S
 ,avg(o.ws) as avg_S, avg(cast(o.ws-m.ws as signed)) as bias_S
 ,std(cast(o.ws-m.ws as signed)) as std_S
 ,sum(if(o.ws  > 5 &&
        m.ws > 5,1,0)) as N_DIR
 ,avg(if(o.ws  > 5 &&
        m.ws > 5,
        if(cast(o.wd-m.wd as signed) between -180 and 180,
           cast(o.wd-m.wd as signed),
           if(cast(o.wd-m.wd as signed) > 180,
              cast(o.wd-m.wd as signed)-360,
              cast(o.wd-m.wd as signed)+360)),null)) as bias_DIR
 ,std(if(o.ws  > 5 &&
        m.ws > 5,
        if(cast(o.wd-m.wd as signed) between -180 and 180,
           cast(o.wd-m.wd as signed),
           if(cast(o.wd-m.wd as signed) > 180,
              cast(o.wd-m.wd as signed)-360,
              cast(o.wd-m.wd as signed)+360)),null)) as std_DIR
 ,std(sqrt(pow(o.ws,2)+pow(m.ws,2)-2*o.ws*m.ws*cos((o.wd-m.wd)/57.2958)))
    as std_W
 ,avg(sqrt(pow(o.ws,2)+pow(m.ws,2)-2*o.ws*m.ws*cos((o.wd-m.wd)/57.2958)))
    as avg_W
 ,sqrt(sum(pow(o.ws,2)+pow(m.ws,2)-2*o.ws*m.ws*cos((o.wd-m.wd)/57.2958))/count(o.wd))
    as rms_W
 ,count(o.dp) as N_Td
 ,avg(o.dp)/10 as avg_Td, avg(o.dp-m.dp)/10 as bias_Td
 ,std(o.dp-m.dp)/10 as std_Td
 from """+model_base+"""_net_short as m,obs as o
 where 1=1
 and m.sta_id = o.sta_id
 and m.time = o.time
 and o.time >= """+str(startSecs) +"""
 and o.time < """+str(endSecs) +"""
 and hour(from_unixtime(o.time)) >= 18
 and hour(from_unixtime(o.time)) <= 21
 group by net
 having N_T > 100
 order by null  # avoid a filesort (but one remains--it may not take much time)
"""

print query
cursor.execute(query)
#r=cursor.fetchall()
n_rows = cursor.rowcount

this_time = int(time.time())
dtime = this_time - last_time
print "create table " + table +str(n_rows) +" rows took" +str(dtime)
last_time = this_time


#table = model_base+"_"+str(n_days)+"day"
table = model_base+"_"+str(n_days)+"day_xue"
query = "drop table if exists "+table
print query
cursor.execute(query)

query = """
create table """+table+""" 
(
 sta_id mediumint not null,
 name varchar(10) not null,
 net varchar(20),
min_time int not null,
max_time int not null,
N_T int unsigned not null,
avg_T float,
bias_T float,
std_T float,
N_S int unsigned not null,
avg_S float,
bias_S float,
std_S float,
N_DIR int unsigned,
bias_DIR float,
std_DIR float,
std_W float,
avg_W float,
rms_W float,
N_Td int,
avg_Td float,
bias_Td float,
std_Td float
)

select o.sta_id,name,stations.net,
 min(o.time) as min_time,max(o.time) as max_time,
 count(o.temp) as N_T,
 avg(o.temp)/10 as avg_T, avg(o.temp-m.temp)/10 as bias_T,
 std(o.temp-m.temp)/10 as std_T,
 count(o.ws) as N_S,
 avg(o.ws) as avg_S,
 avg(cast(o.ws-m.ws as signed)) as bias_S,
 std(cast(o.ws-m.ws as signed)) as std_S,
 sum(if(o.ws  > """+str(S_for_DIR_limit)+""" &&
	m.ws > """+str(S_for_DIR_limit)+""",1,0)) as N_DIR,
 avg(if(o.ws  > """+str(S_for_DIR_limit)+""" &&
	m.ws > """+str(S_for_DIR_limit)+""",
	if(cast(o.wd-m.wd as signed) between -180 and 180,
	   cast(o.wd-m.wd as signed),
	   if(cast(o.wd-m.wd as signed) > 180,
	      cast(o.wd-m.wd as signed)-360,
	      cast(o.wd-m.wd as signed)+360)),null)) as bias_DIR,
 std(if(o.ws  > """+str(S_for_DIR_limit)+""" &&
	m.ws > """+str(S_for_DIR_limit)+""",
	if(cast(o.wd-m.wd as signed) between -180 and 180,
	   cast(o.wd-m.wd as signed),
	   if(cast(o.wd-m.wd as signed) > 180,
	      cast(o.wd-m.wd as signed)-360,
	      cast(o.wd-m.wd as signed)+360)),null)) as std_DIR,
std(sqrt(pow(o.ws,2)+pow(m.ws,2)-2*o.ws*m.ws*cos((o.wd-m.wd)/57.2958)))
    as std_W,
 avg(sqrt(pow(o.ws,2)+pow(m.ws,2)-2*o.ws*m.ws*cos((o.wd-m.wd)/57.2958)))
    as avg_W,
 sqrt(sum(pow(o.ws,2)+pow(m.ws,2)-2*o.ws*m.ws*cos((o.wd-m.wd)/57.2958))/count(o.wd))
    as rms_W,
 count(o.dp) as N_Td,
 avg(o.dp)/10 as avg_Td, avg(o.dp-m.dp)/10 as bias_Td,
 std(o.dp-m.dp)/10 as std_Td
 from """+model_base+"""_net_short as m,obs as o,stations
 where m.sta_id = o.sta_id
 and o.sta_id = stations.id
 and m.time = o.time
 and o.time >= """+str(startSecs) +"""
 and o.time < """+str(endSecs) +"""
 and hour(from_unixtime(o.time)) >= 18
 and hour(from_unixtime(o.time)) <= 21
 group by m.sta_id
 having N_T > 14
 order by null
"""
print "wei",query

cursor.execute(query)

n_rows = cursor.rowcount

this_time = int(time.time())
dtime = this_time - last_time
print "create table " + table + str(n_rows) +" rows took" +str(dtime)
last_time = this_time

cursor.close()
if os.path.exists("tmp"):
    os.chdir("tmp")
#    os.system('pwd')
#    print "allfiles=",os.listdir("tmp/")

    current_time=time.time()
    print "current_time",current_time
    for file in os.listdir("."):

       filetime= os.path.getmtime(file)
       diff= current_time-filetime
       if diff > 1.0*24*3600:
          print "removing file "+file
          os.remove(file)

print "NORMAL TERMINATION"

