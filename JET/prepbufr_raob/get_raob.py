#!/usr/bin/python
import sys
import os
from string import *
import time
import subprocess

reprocess = False
try:
    hrs_ago = abs(int(sys.argv[1]))
    print('hours ago: {}'.format(hrs_ago))
except IndexError:
    hrs_ago=0
    
run_time1 = time.time() - hrs_ago*3600
# put on 12-hour boundary
run_time1 -= run_time1 % (12*3600)

tstruct = time.gmtime(run_time1)

ymd_str = "{}{m:02d}{d:02d}".\
          format(tstruct.tm_year,m=tstruct.tm_mon,d=tstruct.tm_mday)
ymdh_str = "{}{m:02d}{d:02d}{h:02d}".\
           format(tstruct.tm_year,m=tstruct.tm_mon,d=tstruct.tm_mday,h=tstruct.tm_hour)
yjdh_str = "{}{j:03d}{h:02d}".\
           format(tstruct.tm_year,j=tstruct.tm_yday,h=tstruct.tm_hour)
h_str = "{h:02d}".format(h=tstruct.tm_hour)

template_file="namelist.template"
output_file="namelist.input"
fout = open(output_file,'w')
with open(template_file) as fp:
    while True:
        line = fp.readline()
        if line:
            line = line.replace('YMDH',ymdh_str)
            line = line.replace('YMDonly',ymd_str)
            line = line.replace('YJDH',yjdh_str)
            line = line.replace('HH',h_str)
        else:
            break
        fout.write(line)
fout.close()
soundings_filename = None
mysql_filename = None
result =subprocess.check_output(['prepbufr2txt.exe'])
r = iter(result.splitlines())
cnt=0
while True:
    try:
        line = next(r)
    except StopIteration:
        break
    #print("{}: {}".format(cnt,line))
    cnt += 1
    if "soundings filename is" in line:
        #print("FOUND")
        items = line.split('|')
        soundings_filename = items[1]
    if "mysql filename is" in line:
        items = line.split('|')
        #print("FOUND")
        mysql_filename = items[1]

if(soundings_filename == None or mysql_filename == None):
    print("no RAOBs to process. Exiting")
    sys.exit()
print('files: {} {}'.format(soundings_filename,mysql_filename))

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
