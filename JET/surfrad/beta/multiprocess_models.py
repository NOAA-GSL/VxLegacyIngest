#!/usr/bin/python
from multiprocessing import Process, Pipe,Manager
import sys
import os
from string import *
from numpy import *
import time

# local modules:
import process_forecast

BAD = float(nan)

class Station:
    """A surfrad or isis station"""
    def __init__(self,id,lat,lon,elev):
        self.id = id
        self.lat = lat
        self.lon = lon
        self.elev = elev
    
 # main program
if __name__== '__main__':
   os.environ['PYTHONUNBUFFERED'] = str(1)
   start_secs = time.time()

   stations = []
   f = open("stations.txt","r")
   allLines = f.readlines()
   for line in allLines:
      data = line.split("|")
      id = data[0]
      lat = float(data[3])
      lon = float(data[4])
      elev = float(data[5])
      #print id,lat,lon,elev
      x = Station(id,lat,lon,elev)
      stations.append(x)

   run_time1 = time.time()
   # put on hour boundary
   run_time1 -= run_time1 % 3600
   # and subtract the requested number of hours
   hrs_ago = abs(int(sys.argv[1]))

   # see if we want to force reprocessing
   reprocess = False
   if len(sys.argv) > 2 and abs(int(sys.argv[2])) > 0:
       reprocess = True
       print "REPROCESSING DATA\n"

   run_time1 -= hrs_ago*3600
   # check 14 hrs ago to get WRF_solar data, that generally comes in at 17:45
   # so the 19Z run should pick up WRF_solar
   run_times = [run_time1,run_time1-3600,run_time1-3*3600,run_time1-14*3600]
   #run_times = [ 1428019200]
   for run_time in run_times:
    run_str = time.strftime("%a, %d %b %Y %H:%M:%S %Z", time.gmtime(run_time))
    print "run time to process: ", run_str
    
    models = ['WRF_solar','RAP_130','RAP_OPS_130']
    models = ['RAP_OPS_130']
    #fcst_lens_mins = [18*60]
    n_nodes = 8
    manager = Manager()
    ns = manager.Namespace()
    ns.n_good = 0
    jobs = []
    surfrad_start = time.time()
    for model in models:
       print "processing",model
       if model == "WRF_solar":
           # run time is always zero Z for WRF_solar
            if run_time % (24*3600) != 0:
                print "breaking out. next model"
                continue
            scales = [3,13,20,40]    # scales in km
            max_fcst_in_hrs = 23
            #max_fcst_in_hrs = 0
            fcst_lens_mins = range(0,max_fcst_in_hrs*60+1,60)
       elif "RAP" in model:
           scales = [13,20,40]    # scales in km
           fcst_lens_mins = range(0,18*60+1,60)
       elif "HRRR" in model:
           scales = [3,13,20,40]    # scales in km
           fcst_lens_mins = range(0,14*60+1,60)
           
       model_start = time.time()
       nf = 0
       for fcst_len_mins in fcst_lens_mins:
          j = Process(target=process_forecast.go,name=model+"-"+str(fcst_len_mins),
                      args=(ns,reprocess,stations,scales,model,run_time,fcst_len_mins,BAD))
          j.start()
          pid = j.pid
          jobs.append((j,pid))
          nf += 1
          if nf%n_nodes == 0 or nf == len(fcst_lens_mins):
              print "length of jobs is",len(jobs)
              for jp in jobs:
                  job = jp[0]
                  pid = jp[1]
                  job.join()  # wait for each job to finish
                  print "job",job.name,"with pid",pid,"took",job.exitcode,"seconds"
              manager.shutdown()
              manager = Manager()
              ns = manager.Namespace()
              ns.n_good = 0
              jobs = []
    surfrad_end = time.time()
    surfrad_secs = surfrad_end - surfrad_start
    print "all forecasts/models run at", run_str,"took",int(surfrad_secs),"seconds"
    
   # clean up tmp/ directory (where qsub output files are stored
   os.chdir("tmp/")
   time_lag= 12*3600
   curtime = time.time()
   all_files = os.listdir(".")
   for each_file in all_files:
    #print "file is",each_file
    ftime = os.stat(each_file).st_mtime
    difftime = curtime - ftime
    if difftime > time_lag:
      print "removing",each_file
      os.remove(each_file)

   end_secs = time.time()
   proc_secs = end_secs - start_secs
   print "entire job took",int(proc_secs),"secs"
   sys.exit(int(proc_secs))

  
                  
                  
                  