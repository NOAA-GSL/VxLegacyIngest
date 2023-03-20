#!/usr/bin/env python
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
    """A madis mesonet station"""
    def __init__(self,id,lat,lon,elev):
        self.id = id
        self.lat = lat
        self.lon = lon
        self.elev = elev

        
 # main program
if __name__== '__main__':
   os.environ['PYTHONUNBUFFERED'] = str(1)
   start_secs = time.time()

 
   n_nodes = int(sys.argv[1])
   print "nodes to be used:",n_nodes
   hrs_ahead = 0
   if len(sys.argv) > 2 and abs(int(sys.argv[2])) > 0:
       hrs_ahead = int(sys.argv[2])
       print "processing",hrs_ahead,"hours ahead"
   valid_time1 = time.time() +  hrs_ahead*3600
   # put on an hour boundary
   valid_time1 -= valid_time1 % 3600

   # see if we want to force reprocessing
   reprocess = False
   if len(sys.argv) > 3 and abs(int(sys.argv[3])) > 0:
       reprocess = True
       print "REPROCESSING DATA\n"
   valid_times = [valid_time1- i*3600 for i in range(0,9,3)]
   #valid_times = [  1524556800]
   print 'valid_times',valid_times
   #sys.exit(1)
   models = ['HRRR_OPS_old']
   for valid_time in valid_times:
    valid_str = time.strftime("%a, %d %b %Y %H:%M:%S %Z", time.gmtime(valid_time))
    print "valid time to process: ", valid_str

    stations = []
    try:
       f = open("tmp_real/pcp_mesonet_stations."+str(int(valid_time))+".txt","r")
    except:
       print "tmp_real/pcp_mesonet_stations."+str(int(valid_time))+".txt not found!"
       continue
    allLines = f.readlines()
    for line in allLines:
      data = line.split(" ")
      id = data[0]
      lat = float(data[1])   # in decimal degrees
      lon = float(data[2])   # in decimal degrees
      elev = float(data[3])  # in feet
      #print id,lat,lon,elev
      x = Station(id,lat,lon,elev)
      stations.append(x)

    n_good = 0
    manager = Manager()
    ns = manager.Namespace()
    ns.n_good = 0
    jobs = []
    time_start = time.time()
    for model in models:
        model_start = time.time()
        if True:
            # need all these fcst_lens to allow 3h precip comparisons at fcst_lens = 15,18,24,30,36, to compare w/ GFS
            fcst_lens = [12] #,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,22,23,24,28,29,30,34,35,36]
            if model.startswith("GFS"):
                fcst_lens = [6] #,4,5,6,7,8,9,12,15,18,24,30,36,48,72,96,120,168,240]
            elif model.startswith("NBM"):
                fcst_lens = [1,2,3,4,5,6,7,8,9,12,15,18,24,30,36,48,72,96,120,168,240]
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
   sys.exit(0)

  
                  
                  
                  
