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
    """A 1min ASOS station"""
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
   f = open("1min_asos.txt","r")
   allLines = f.readlines()
   for line in allLines:
      data = line.split("\t")
      id = data[0]
      lat = float(data[1])   # in decimal degrees
      lon = float(data[2])   # in decimal degrees
      elev = float(data[3])  # in feet
      #print id,lat,lon,elev
      x = Station(id,lat,lon,elev)
      stations.append(x)

   n_nodes = int(sys.argv[1])
   print "nodes to be used:",n_nodes
   hrs_ago = 0
   if len(sys.argv) > 2 and abs(int(sys.argv[2])) > 0:
       hrs_ago = abs(int(sys.argv[2]))
       print "processing",hrs_ago,"hours ago"
   valid_time1 = time.time() -  hrs_ago*3600
   # put on an hour boundary
   valid_time1 -= valid_time1 % 3600

   # see if we want to force reprocessing
   reprocess = False
   if len(sys.argv) > 3 and abs(int(sys.argv[3])) > 0:
       reprocess = True
       print "REPROCESSING DATA\n"
   # look for valid times in the future to get long-range forecasts from current runs. 
   #valid_times = [valid_time1,valid_time1-6*3600,valid_time1-12*3600,
     #             valid_time1+3*24*3600,valid_time1+6*24*3600,valid_time1+10*24*3600,]
   valid_times = [valid_time1] # - i*3600 for i in range(0,9,3)]
   #valid_times = [  1524556800]
   print 'valid_times',valid_times
   #sys.exit(1)
   for valid_time in valid_times:
    valid_str = time.strftime("%a, %d %b %Y %H:%M:%S %Z", time.gmtime(valid_time))
    print "valid time to process: ", valid_str

    models = ['HRRR_GSD']
    n_good = 0
    manager = Manager()
    ns = manager.Namespace()
    ns.n_good = 0
    jobs = []
    time_start = time.time()
    for model in models:
       model_start = time.time()
       if model.find("HRRR") >= 0:
           fcst_lens = [1,2,3,4,5,6,7,8,9,12,15,18]

       nf=0
       for fcst_len in fcst_lens:
          j = Process(target=process_forecast.go,name=model+"-"+str(fcst_len),
                      args=(ns,stations,fcst_len,reprocess,model,valid_time,fcst_len,BAD))
          j.start()
          pid = j.pid
          jobs.append((j,pid))
          nf += 1
          if nf%n_nodes == 0 or nf == len(fcst_lens):
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
    time_end = time.time()
    process_secs = time_end - time_start
    print "all forecasts/models valid at", valid_str,"took",int(process_secs),"seconds"

   end_secs = time.time()
   proc_secs = end_secs - start_secs
   print "entire job took",int(proc_secs),"secs"
   #sys.exit(int(proc_secs))

  
                  
                  
                  
