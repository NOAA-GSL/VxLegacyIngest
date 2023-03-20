#!/usr/bin/env python
import os
import sys
import time
import MySQLdb
import copy
import MySQLdb.cursors
from make_subregion_sums3 import *

# main program
if __name__== '__main__':
   os.environ['PYTHONUNBUFFERED'] = str(1)
   start_secs = time.time()
   hrs_ago = 0
   if len(sys.argv) > 1 and abs(int(sys.argv[1])) > 0:
       hrs_ago = abs(int(sys.argv[1]))
       print "processing",hrs_ago,"hours ago"
   valid_time1 = time.time() -  hrs_ago*3600
   # put on an hour boundary
   valid_time1 -= valid_time1 % 3600

   # see if we want to force reprocessing
   reprocess = False
   if len(sys.argv) > 2 and abs(int(sys.argv[2])) > 0:
       reprocess = True
       print "REPROCESSING DATA\n"
   valid_times = [valid_time1- i*3600 for i in range(0,9,3)]
   #valid_times = [  1524556800]
   print 'valid_times',valid_times
   models = ['NBM','RAP_OPS','RAP_GSD','HRRR_OPS','HRRR_GSD']
   regions = ['ALL_HRRR','E_HRRR','W_HRRR','AQPI_LARGE','AQPI_HI','AQPI_LO','AQPI_SIERRA']
   
 # conect to database
   try:
    connection = MySQLdb.connect("wolphin.fsl.noaa.gov",
                                 user="wcron0_user",passwd="cohen_lee",
                                 db="precip_mesonets2",local_infile=True,
                                 cursorclass=MySQLdb.cursors.DictCursor)
   except MySQLdb.Error, e:
    print "Error %d: %s" % (e.args[0], e.args[1])
    sys.exit (1)
   connection.get_warnings = True
   cursor = connection.cursor()

   for model in models:
     for valid_time in valid_times:
        model_start_secs= time.time()
        accum = 1
        # need all these fcst_lens to allow 3h precip comparisons at fcst_lens = 15,18,24,30,36, to compare w/ GFS
        fcst_lens = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,22,23,24,28,29,30,34,35,36]
        if model.startswith("GFS"):
             fcst_lens = [1,2,3,4,5,6,7,8,9,12,15,18,24,30,36,48,72,96,120,168,240]
        elif model.startswith("NBM"):
             fcst_lens = [1,2,3,4,5,6,7,8,9,12,15,18,24,30,36,48,72,96,120,168,240]
             
        for fcst_len in fcst_lens:     
            if reprocess == False and processed(cursor,model,regions[0],valid_time,fcst_len):
                print("{model} for valid time {vt}, fcst_len {fl} already processed.".\
                      format(model=model,vt=valid_time,fl=fcst_len))
                continue
            make_subregion_sums3(cursor,model,regions,valid_time,fcst_len,accum)    
        model_end_secs = time.time()
        print "All forecasts for {model} valid {vt_str} processed in {secs:.1f} secs\n".\
           format(secs=model_end_secs-model_start_secs,model=model,\
              vt_str = time.strftime("%a, %d %b %Y %H:%M:%S %Z", time.gmtime(valid_time)))

  
