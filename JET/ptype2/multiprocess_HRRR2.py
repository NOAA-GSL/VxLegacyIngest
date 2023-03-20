#!/usr/bin/env python
from multiprocessing import Process, Pipe,Manager
import sys
import os
import warnings
from string import *
from numpy import *
import time

# local modules:
import process_forecast

BAD = float(nan)

class Station:
    """A METAR station"""
    def __init__(self,id,lat,lon,elev):
        self.id = id
        self.lat = lat
        self.lon = lon
        self.elev = elev
    
 # main program
if __name__== '__main__':
   warnings.simplefilter('error', UserWarning)
   os.environ['PYTHONUNBUFFERED'] = str(1)
   start_secs = time.time()
   
   stations = []
   f = open("stations.txt","r")
   allLines = f.readlines()
   for line in allLines:
      data = line.split()
      id = data[0]
      lat = float(data[2])/100
      lon = float(data[3])/100
      elev = float(data[4])
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
   run_times = [run_time1, run_time1-3600, run_time1-3*3600, run_time1-6*3600]
   #run_times = [ 1470376800] 
   for run_time in run_times:
    run_str = time.strftime("%a, %d %b %Y %H:%M:%S %Z", time.gmtime(run_time))
    print "run time to process: ", run_str

    models = ['HRRR','RAP_130','NAMnest_OPS_227']
    #models = ['NAMnest_OPS_227']
    max_fcst_hour = 15
    n_nodes = 12  # changed from 8 WRM 8/4/16
    manager = Manager()
    ns = manager.Namespace()
    ns.n_good = 0
    jobs = []
    surfrad_start = time.time()
    for model in models:
       if "RAP" in model:
            scales = [13,26,52]  # scales in km
            fcst_lens_mins = range(60,max_fcst_hour*60+1,60)
       elif "NAM" in model:
            scales = [3,13,26,52]  # scales in km
            fcst_lens_mins = range(60,max_fcst_hour*60+1,60)
       else:
            scales = [3,13,26,52]    # scales in km
            fcst_lens_mins = range(15,max_fcst_hour*60+1,15)
            # fcst_lens_mins = [15]
       model_start = time.time()
       print 'fcst_lens_mins',fcst_lens_mins
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
    
   end_secs = time.time()
   proc_secs = end_secs - start_secs
   print "entire job took",int(proc_secs),"secs"
   sys.exit(0)

  
                  
                  
                  
