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

def already_processed ( data_source,valid_time,fcst_len,region,DEBUG) :
    sec_of_day = valid_time%(24*3600)
    desired_hour = sec_of_day/3600
    desired_valid_day = valid_time - sec_of_day
    print data_source,valid_time,fcst_len,region,DEBUG 
    query = """
select count(*) from surface_sums."""+data_source+"""_"""+str(fcst_len)+"""_metar_"""+region+"""
where valid_day = """+str(desired_valid_day)+""" and hour = """+ str(desired_hour)

    print query
    cursor.execute(query);

    sth = cursor.fetchall()
    n  = sth[0][0]
    print "n=",n
    return n





thisDir = os.getenv("SGE_O_WORKDIR")

if os.getenv("SGE_O_WORKDIR"):
   thisDir = os.getenv("SGE_O_WORKDIR")
else:
    basename=sys.argv[0]
    thisDir = "./"


DEBUG=1

#change to the proper directory

if os.path.exists(thisDir):
    os.chdir(thisDir)
else:
    print "Content-type: text/html\n\nCan't cd to "+thisDir
    sys.exit(0)
    
print thisDir
thisDir = os.getenv("PWD")
print thisDir


n_zero_ceilings = 0
n_stations_loaded = 0

#if  DEBUG:
#    foreach my $key (sort keys(%ENV)) {
#        print "$key: $ENV{$key}\n";
#    }
#    print "thisDir is $thisDir\n";
#    print "\n";
#}




#$|=1;  #force flush of buffers after each print
#open (STDERR, ">&STDOUT") || die "can't dup stdout ($!)\n";

os.environ["PATH"]="/bin"
os.environ["CLASSPATH"] = os.path.join("/misc/ihome/moninger/javalibs/mysql/mysql-connector-java-3.1.13-bin.jar:",".")

#$SIG{ALRM} = \&my_timeout;
month_num = {"Jan": 1, "Feb": 2, "Mar" : 3, "Apr" : 4, "May" : 5, "Jun" : 6,
             "Jul" : 7, "Aug" : 8, "Sep" : 9, "Oct" :10, "Nov" :11, "Dec" :12}


os.environ['TZ']="GMT"
os.environ["DBI_USER"] = "wcron0_user"
os.environ["DBI_PASS"] = "cohen_lee"
os.environ["DBI_DSN"] = "DBI:mysql:madis3:wolphin"

connection = MySQLdb.connect("wolphin",user="wcron0_user",passwd="cohen_lee",db="madis3")
cursor = connection.cursor()

# 0 argv is this program name  sys.argv[0] = surface_driver.py

hours_ago = abs(int(sys.argv[1]))
print "hours_ago is $hours_ago\n";
if len(sys.argv)>2:
   db_machine = sys.ARGV[2]
else:
   db_machine= "wolphin"

if len(sys.argv)>3:
   db_name = sys.ARGV[3]
else:
   db_name= "madis3"

# current time in seconds
mytime = time.time();
# get on hour boundary
mytime = mytime - mytime%3600 - hours_ago*3600
valid_times = [mytime,mytime-1*3600,mytime-3*3600,mytime-8*3600]
print mytime
print valid_times

# loop through model
for  data_source in ["RR1h", "Bak13", "HRRR"]:
    print "############################################"
    print "starting data_source " + data_source
    print "############################################"
    if data_source =="HRRR":
	regions = ["ALL_HRRR" "E_HRRR" "W_HRRR"]
	fcst_lens = (0,1,3,6,9,12)
	WRF=1
    if  data_source ==  "RR1h":
	regions = ["ALL_RR1", "ALL_RUC", "E_RUC", "W_RUC", "ALL_HRRR", "E_HRRR", "W_HRRR"]
	fcst_lens = (0,1,3,6,9,12)
	WRF=1
    if data_source == "Bak13":
	regions = ["ALL_RUC", "E_RUC", "W_RUC", "ALL_HRRR", "E_HRRR", "W_HRRR"]
	fcst_lens = (1,6)
	WRF=0
    # loop through fcst_len
    for  fcst_len  in  fcst_lens:
       print "########################"
       print "starting fcst_lens "+str(fcst_len) 
       print "########################"
       # loop through valid_time
       for  valid_time in  valid_times:
         print "###############"
         print "starting valid_time " +str(valid_time)
         print "###############"
         valid_str = time.ctime(valid_time)
         run_time = valid_time - fcst_len * 3600
#         print "valid_str=",valid_str
#         print "run_time=",run_time
#         print "fcst_len=",fcst_len

        

         if already_processed(data_source,valid_time,fcst_len,regions[0],DEBUG) >0:
             print "ALREADY LOADED: "+ data_source+ str(fcst_len) +"h fcst valid at "+ valid_str
             continue
         else :
             print "TO PROCESS: "+str(fcst_len) +"h fcst valid at"+ valid_str

         #################################################    
         # get wgrib file name in the right directory
         #################################################
         start = ""			# not looking for 'latest'
         file,type= get_iso_file3.get_iso_file3(month_num,run_time,data_source,DEBUG,fcst_len,start)


         if os.path.isfile(file) :
             print "FILE FOUND "+data_source + str(fcst_len)+" h fcst valid at "+valid_str

         else:    
             print "file not found for" +data_source + str(fcst_len)+" h fcst valid at "+valid_str
             continue

         ####################################
         # get wgrib file information
         ####################################
         la1,lo1,lov,latin1,nx,ny,dx,grib_type,grid_type,valid_date,fcst_proj= get_grid.get_grid(file,thisDir,DEBUG)


         
         tt= (valid_date.year,valid_date.month, valid_date.day,valid_date.hour, valid_date.minute, valid_date.second,valid_date.weekday(),0,0)
         valid_time_from_file = time.mktime(tt)

#         print "valid_time=",valid_time
#         print "valid_time_from_file=",valid_time_from_file

         if valid_time_from_file !=  valid_time:
             print "BAD VALID TIME from file: "+ str(valid_time_from_file)
             sys.exit(1)
             
         # for HRRR and RR 
         if grib_type == 1 and WRF == 1:

             ###????   interp wgrib file to stn obs location, write to database
             arg = thisDir+"/surface_HRRR.x "+\
             data_source +" "+ str(int(valid_time))+" "+file+" "+ str(fcst_len) +" "+\
             str(la1)+" "+str(lo1)+" "+str(lov)+" "+str(latin1)+" "+str(dx) +" "+\
             str(nx)+" "+str(ny)+" 1 "+str(DEBUG)


             if DEBUG :
                 print "gribtype=1 and wrf=1 arg is "+arg

             a = os.popen(arg)
             if a:
                 allrecs = a.read()
                 out= re.findall("(\d+) stations loaded",allrecs)
                 n_stations_loaded = out[0]
             
                 print " RR zeros: "+ str(n_zero_ceilings)+" loaded: "+str(n_stations_loaded)
#                 sys.exit(0)
             else:
                 sys.exit(0)
         # for ruc
         elif grib_type == 1 and WRF == 0 :
             dx_km = dx/1000;
             arg = thisDir+"/agrib_madis_sites.x "+db_machine+" "+db_name+" "+\
             data_source+" "+str(int(valid_time))+" "+file+" "+str(fcst_len)+" "+\
             str(la1)+" "+str(lo1)+" "+str(lov)+" "+str(latin1)+" "+str(dx_km)+" "+\
             str(nx)+" "+str(ny)+" 1 "+str(DEBUG)

             if DEBUG:
                 print "arg is "+arg

             a = os.popen(arg)
             if a:
                 allrecs = a.read()
                 out= re.findall("(\d+) stations loaded",allrecs)
                 n_stations_loaded = out[0]
             
                 print "RUC zeros: "+str(n_zero_ceilings)+" loaded: "+str(n_stations_loaded)

             else:
                 sys.exit(0)
    
         elif grib_type != 1 :
             print "cannot do grib2 files yet!!"
             sys.exit(0)



         if n_stations_loaded > 0:
             for region in regions:
                 update_summaries3.update_summaries3(data_source,valid_time,fcst_len,region,cursor,db_name,DEBUG)

         else :
             print "NOT GENERATING SUMMARIES\n\n";


if os.path.exists("tmp"):
    os.chdir("tmp")

    current_time=time.time()
    print "current_time",current_time
    for file in os.listdir("."):

       filetime= os.path.getmtime(file)
       diff= current_time-filetime
       if diff > 0.7*24*3600:
          print "removing file "+file
          os.remove(file)

print "NORMAL TERMINATION"
 



