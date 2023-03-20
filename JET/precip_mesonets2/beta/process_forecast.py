import sys
from string import *
from numpy import *
#import math
import time
import multiprocessing

# local modules:
from read_hrrr import *
from read_gfs import *
from write_station_values import *

def unprocessed(model,valid_time,fcst_len):
    # this will only work for items processed < 12 h ago, because of scrubbing on the tmp directory!
    result = True
    all_files = os.listdir("tmp/")
    for each_file in all_files:
        if each_file.find(".PCP_1h_data.loaded") > 0 or \
           each_file.find(".PCP_1h_data.written") > 0 : # might not have been loaded yet
            #print each_file
            #print model,sat,valid_time,fcst_len
            item = each_file.split(".")
            pid = item[0]
            found_valid_time = int(item[1])
            found_model = item[2]
            found_fcst_len = int(item[3])
            if model == found_model and \
                    valid_time == found_valid_time and \
                    fcst_len == found_fcst_len:
                result = False
    #print "result of unprocessed is",result
    return(result)                

def go(ns,stations,name,reprocess,model,valid_time,fcst_len,BAD):
  print_file =   "tmp/%d.%d.%s.%d.PCP_1h.output" % \
      (os.getpid(),valid_time,model,fcst_len)
  # comment the line below if you want all the output to stdout (different threads intermixed)
  #sys.stdout = open(print_file,'w',0)
  start_secs = time.time()
  current = multiprocessing.current_process()
  current.name = str(name)
    
  print("%d processing %s %d %d" % (os.getpid(),model,valid_time,fcst_len))
  if True:
    good = False
    if True:
        if reprocess or unprocessed(model,valid_time,fcst_len):
            if True:
                if model.startswith("GFS"):
                    (proj,good,PCP) = read_gfs(model,valid_time,fcst_len)
                    if good:
                        write_station_values(proj,stations,model,valid_time,fcst_len,PCP,accum=3)
                else:
                    (proj,good,PCP) =  read_hrrr(model,valid_time,fcst_len)
                    if good:
                        write_station_values(proj,stations,model,valid_time,fcst_len,PCP,accum=1)

        else:
            print("%d %s %d h fcst valid %s already processed" %\
                      (os.getpid(),model,fcst_len,
                       time.strftime("%Y-%m-%d %H Z", time.gmtime(valid_time))))
  else:
      print "sleeping"
      time.sleep(1+fcst_len)
  end_secs = time.time()
  proc_secs = end_secs - start_secs
  sys.exit(int(proc_secs))
    
    
