#!/usr/bin/python
import sys
import os
from string import *
import time
import subprocess
from RaobNames import name, plymouth

soundings_dict = {}
soundings_count = {}

def write_sounding(output_sdg_list, wmoid,date,cursor,write_to_db):
    output_sdg = ''.join(output_sdg_list)
    this_sdg_len = len(output_sdg)
    try:
        soundings_count[wmoid] += 1
        last_sdg_len =  len(soundings_dict[wmoid])
        if(this_sdg_len < last_sdg_len):
           print("dup sdg for {}. This one is shorter ({}) than the previous ({}), so abandon this.".\
                 format(wmoid,this_sdg_len,last_sdg_len))
           # this is a dup sounding for the same wmoid, and has less data than
           # what's already been written. So abandon this one
           return
        else:
           print("dup sdg for {}. This one is longer ({}) than the previous ({})".\
                 format(wmoid,this_sdg_len,last_sdg_len)+", so replace the other with this.")
    except(KeyError):
           # no previous sounding for this wmoid
           soundings_count[wmoid] =1
           # and this sounding will replace the previous, shorter, sdg in the db.
     
    soundings_dict[wmoid] = output_sdg
   # now zip it up
    try:
        from StringIO import StringIO  # Python 2.7
    except ImportError:
        from io import StringIO  # Python 3.x
    import gzip
    gzipped_output_sdg = StringIO()
    with gzip.GzipFile(fileobj=gzipped_output_sdg, mode="w") as f:
        f.write(output_sdg.encode())
 
    query = "replace into RAOB_raob_soundings (site,time,s) values(%s,%s,%s)"
    args = (wmoid,date,gzipped_output_sdg.getvalue())
    #print("{} wrote RAOB for time {}".format(wmoid,date))
    try:
        if(write_to_db):
            cursor.execute(query,args)
        #else:
            #print("db not written to")
    except (MySQLdb.Error, MySQLdb.Warning) as e:
            print("MYSQL ERROR: {}".format(e))
    
month_num = {
     'JAN':1,'FEB':2,'MAR':3,'APR':4,'MAY':5,'JUN':6,
     'JUL':7,'AUG':8,'SEP':9,'OCT':10,'NOV':11,'DEC':12}

write_to_db = True
namelist_type_found = False
try:
    namelist_type = sys.argv[1]
    namelist_type_found = True
    hrs_ago = abs(int(sys.argv[2]))
    print('hours ago: {}'.format(hrs_ago))
except IndexError:
    hrs_ago=0
try:
    reprocess = int(sys.argv[3])
except IndexError:
    reprocess = 0

if(namelist_type_found == False):
    print("usage: get_prepbufr_raobs2.py namelist_type [hours_ago] [1 to reprocess]")
    sys.exit(1)
    
print("prepbufr type is {}".format(namelist_type))

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
y2jdh_str = "{y:02d}{j:03d}{h:02d}".\
           format(y=tstruct.tm_year-2000,j=tstruct.tm_yday,h=tstruct.tm_hour)
h_str = "{h:02d}".format(h=tstruct.tm_hour)
sql_time_str = "{}-{m:02d}-{d:02d} {h:02d}:00:00".\
               format(tstruct.tm_year,m=tstruct.tm_mon,d=tstruct.tm_mday,h=tstruct.tm_hour)

# check to see whether we already have RAOBs for this time.
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
query= """select count(*) N
from RAOB_raob_soundings
where time = '{}'
""".format(sql_time_str)
#print(query)
result_ste = cursor.execute(query)
n_raobs = int(cursor.fetchone()[0])
#print("n raobs: {}".format(n_raobs))
if(reprocess == 0 and n_raobs > 400):
    print("{} RAOBs have already been loaded for {} (more than 400 \
considered good). Quitting. Use reprocess argument to reprocess".\
          format(n_raobs,sql_time_str))
    sys.exit(1)

pb_output_dir = "tmp/"
template_file="namelist.{}.template".format(namelist_type)
namelist_file="{}{}.namelist.input".format(pb_output_dir,os.getpid())
fout = open(namelist_file,'w')
with open(template_file) as fp:
    while True:
        line = fp.readline()
        if line:
            line = line.replace('YMDH',ymdh_str)
            line = line.replace('Y2JDH',y2jdh_str)
            line = line.replace('YJDH',yjdh_str)
            line = line.replace('YMDonly',ymd_str)
            line = line.replace('HH',h_str)
            line = line.replace('SAVEPATH',pb_output_dir)
            #
        else:
            break
        fout.write(line)
fout.close()
bad_winds_filename = "{}{}.bad_winds.tmp".format(pb_output_dir,os.getpid())
bw_out = open(bad_winds_filename,'w')
soundings_filename = None
mysql_filename = None
os.environ["NAMELIST_FILE"] = namelist_file
print("NAMELIST_FILE is {}".format(namelist_file))
cmd = 'prepbufr2txt.try9.exe'
print("command is {}".format(cmd))
try:
    result =subprocess.check_output([cmd])
except subprocess.CalledProcessError:
    print("NO prepbufr file. Quitting.")
    sys.exit(1)
    
r = iter(result.splitlines())
cnt=0
while True:
    try:
        line = next(r)
    except StopIteration:
        break
    print("{}: {}".format(cnt,line))
    cnt += 1
    if "soundings filename is" in line:
        #print("FOUND")
        items = line.split('|')
        soundings_filename = items[1]
    if "mysql filename is" in line:
        items = line.split('|')
        #print("FOUND")
        mysql_filename = items[1]
    if "BAD WIND" in line:
        items = line.split(None)
        newline = '{time:.0f},{wmoid:.0f},{mb:.0f},{dir:.0f},{spd:.0f},\n'.\
                  format(time=run_time1,wmoid=float(items[7]),mb=float(items[8]),dir=float(items[10]),spd=float(items[11]))
        bw_out.write(newline)
        #print(newline)
        
bw_out.close()
if(write_to_db == False):
    print('SKIPPING DB LOAD')
    #sys.exit()

if(soundings_filename == None or mysql_filename == None):
    print("no RAOBs to process. Exiting")
    sys.exit(1)
print('files: {} {}'.format(soundings_filename,mysql_filename))

query = """load data concurrent local infile '{}'
replace into table hypsometric_summary
columns terminated by ','
lines terminated by ',\\n'
(wmoid,time,
mean_h_diff_500,  max_h_diff_500,  n_h_diff_500,  n_added_500,
mean_h_diff,  max_h_diff,  n_h_diff,  n_added)""".format(mysql_filename)
print("query is {}".format(query))
if(write_to_db):
    cursor.execute(query)
else:
    print("DB not written to.")
print("{} wmoid records written to table soundings_pb.hypsometric_summary\n".format(cursor.rowcount))

query = """load data concurrent local infile '{}'
replace into table bad_winds
columns terminated by ','
lines terminated by ',\\n'
(valid_time,wmoid,press,dir,spd)""".format(bad_winds_filename)
print("query is {}".format(query))
if(write_to_db):
    cursor.execute(query)
else:
    print("DB not written to.")
print("{} bad winds  written to table soundings_pb.bad_winds\n".format(cursor.rowcount))

missing_site_names={}
#now load the RAOBS
# read a sounding
input_sdg = open(soundings_filename,'r')
result=input_sdg.readlines()
output_sdg_list=[]
soundings_written=0
for row in result:
    items=row.split()
    if(items[0] == 'RAOB' and items[1] != 'sounding'):
        # finish up any previous sounding
        if(output_sdg_list != []):
            #print("writing sounding |{}| for {}".format(wmoid,date))
            write_sounding(output_sdg_list,wmoid,date,cursor,write_to_db)
            soundings_written += 1
            output_sdg_list=[]
        hour = items[1]
        mday = items[2]
        month = month_num[items[3]]
        year = items[4]
        date = "{y}-{m:02d}-{d:02d} {h:02d}:00:00".\
               format(y=year,m=int(month),d=int(mday),h=int(hour))
        #print("date {}".format(date))
        # add a dummy indices line, so this is similar to the stored model soundings
        output_sdg_list.append("RAOB sounding valid at:\n")
    if(items[0] =='1'):
        # add a dummy indices line, so this is similar to the stored model soundings
        #output_sdg_list.append("   CAPE  99999    CIN  99999  Helic  99999     PW  99999\n")
        # and grab the wmoid
        wmoid = row[14:21].strip()
        #print("wmoid is |{}|".format(wmoid))
    if(items[0] == '3'):
        dummy_name= items[1]
        try:
            site = name[wmoid]
        except KeyError:
            #print("missing site name for {}".format(wmoid))
            site = wmoid
            try:
                site = plymouth[wmoid]
                #print("FOUND in the plymouth list with name {}".format(site))
            except KeyError:
                #print("also not found in plymouth")
                missing_site_names[wmoid]=1
        row="      3          {s:>4}                99999     kt\n".format(s=site)
    output_sdg_list.append(row)
# write the last sounding
write_sounding(output_sdg_list,wmoid,date,cursor,write_to_db)
soundings_written += 1

if(write_to_db):
    print("{} soundings written to database soundings_pb, including...".format(soundings_written))
print("wmoid's for which we have no site names (though we do have locations):")
for wmoid in sorted(missing_site_names.keys()):
    print(wmoid)

filename = "{}RAOBS.{}".format(pb_output_dir,namelist_type)
fout = open(filename,'w')
print("writing {}".format(filename))
for wmoid in sorted(soundings_dict.keys()):
    fout.write(soundings_dict[wmoid])
fout.close()    
sys.exit(0)
