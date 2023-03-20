import sys
import os
from string import *
from numpy import *
#import MySQLdb
#import math
import time
import multiprocessing

# local modules:
from read_model2 import *
from read_netcdf import *
from write_station_values import *

def unprocessed(model,run_time,fcst_len_mins):
    # this will only work for items processed < 12 h ago, because of scrubbing on the tmp directory!
    result = True
    all_files = os.listdir("tmp/")
    #print all_files
    for each_file in all_files:
        if each_file.find(".dswrf_data.loaded") > 0:
            #print each_file
            #print model,run_time,fcst_len
            item = each_file.split(".")
            pid = item[0]
            found_run_time = int(item[1])
            found_model = item[2]
            found_fcst_len_mins = int(item[3])
            if model == found_model and \
                    run_time == found_run_time and \
                    fcst_len_mins == found_fcst_len_mins:
                result = False
    #print "result of unprocessed is",result
    return(result)                

def go(ns,reprocess,stations,scales,model,run_time,fcst_len_mins,BAD):
  print_file =   "tmp/%d.%d.%s.%d.dswrf.output" % \
      (os.getpid(),run_time,model,fcst_len_mins)
  # turn the line below on to get individual output files for each sub-process
  #sys.stdout = open(print_file,'w',0)
  start_secs = time.time()
  current = multiprocessing.current_process()
  #current.name = str(name)
    
  print("%d processing %s %d %d" % (os.getpid(),model,run_time,fcst_len_mins))
  if True:   
    if True:
        if reprocess or unprocessed(model,run_time,fcst_len_mins):
            if model == "WRF_solar":
                (good,proj,BASE,TOP,MODEL_DSWRF) =  read_netcdf(model,run_time,fcst_len_mins)
            else:
                (good,proj,BASE,TOP,MODEL_DSWRF) =  read_model2(model,run_time,fcst_len_mins)
            if good:
                start_stats = time.clock()
                write_station_values(model,run_time,fcst_len_mins,proj,stations,scales,MODEL_DSWRF)
                end_stats = time.clock()
        else:
            print("%d %s %d h fcst run %s already processed" %\
                      (os.getpid(),model,fcst_len_mins,
                       time.strftime("%Y-%m-%d %H Z", time.gmtime(run_time))))
  else:
      print "sleeping"
      time.sleep(1)
  end_secs = time.time()
  proc_secs = end_secs - start_secs
  sys.exit(int(proc_secs))
    
    
