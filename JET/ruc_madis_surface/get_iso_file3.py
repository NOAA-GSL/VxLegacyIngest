def get_iso_file3 (month_num,run_time,data_source,DEBUG,desired_fcst_len,start):

#    my ($out_file,$type,$fcst_len);    
    import os
    import sys
    import MySQLdb
    from time import gmtime,strftime
#    import smtplib
#    from  subprocess import Popen,PIPE
#   import StringIO
    from string import *
#   import random
#    import datetime
    import time
#   import math
    import re
#   import zlib

#    print  "desired_fcst_len" , desired_fcst_len 
    if desired_fcst_len is None: 
	print "must have a desired forecast len"
        sys.exit(0)


    if data_source == "RR1h":
	anal_dir = "/whome/rtrr/rr/WRFDATE/postprd/"
    elif data_source == "RRnc":
	anal_dir = "/whome/wrfruc/rr_nocyc/WRFDATE/postprd/"
    elif data_source == "RR1h_dev":
	anal_dir = "/whome/rtrr/rr_devel/WRFDATE/postprd/"
    elif data_source == "HRRR":
	anal_dir = "/whome/rtrr/hrrr/WRFDATE/postprd/"
    elif data_source == "Bak13":
	anal_dir = "/whome/rtruc/ruc_backup/ruc_presm/"
    else :
	anal_dir = data_source+"_grib_dir"

    if  DEBUG:
	print "data source is "+ data_source
	print "Looking in directory "+ anal_dir
    
    # the hardest part if to get the suffix
    suffix = ".grib"

    if re.search( "/grib2",anal_dir) or re.search("/gsd/fim/grib",anal_dir) or re.search("rtfim/FIM/",anal_dir) :
	suffix = ""
    elif re.search("/rt1/rtruc/13km/run/maps_fcst",anal_dir):
	suffix = ".grib2"

    year,mon,mday,hour,min,secs,wday,yday,isdst =time.gmtime(run_time)
#    print time.ctime(run_time)

#    print "year=",year,"mon=",mon,"mday=",mday,"hour=",hour,"min=",min,"secs =",secs
#    print "wday=",wday
#    print "yday=",yday
#    print "isdst=",isdst

#    hour = hour-1
#    print "anal_dir="
    if re.search("WRFDATE",anal_dir):
        fim_date="%04d"%year+"%02d"%mon+"%02d"%mday+"%02d"%hour
#        print "fim_date=",fim_date
#        sys.exit(0)
        
        anal_dir = anal_dir.replace("WRFDATE",fim_date)
#        print anal_dir
        base_file = "WRFNAT"+"%02d"%desired_fcst_len+".tm00"
#        print base_file

        if re.search("^RR",data_source):
            if  desired_fcst_len == 0:
            	base_file = "wrfprs_rr_"+"%02d"%desired_fcst_len+".al00"
	    else: 
		base_file = "wrfprs_rr_"+"%02d"%desired_fcst_len+ ".grib1"

	elif re.search("^HRRR",data_source):
	    base_file = "wrfprs_hrconus_"+"%02d"%desired_fcst_len+".grib1"
	
	filename = anal_dir+base_file
    else :
	# RUC-style filename
	filename = anal_dir+"%02d"%(year%100)+"%03d"%yday+"%02d"%hour+"000"+"%03d"%desired_fcst_len+suffix


    if DEBUG :
	print "filename is "+ filename
#    print data_source

     
    if not os.path.isfile(filename):
#	# file not found. see if $data_source was the entire file name
        if os.path.isfile(data_source):
	    filename = data_source
	else :
	    filename = ""


    return filename,0
    
