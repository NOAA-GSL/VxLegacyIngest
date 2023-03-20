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

   print "usage for realtime: multiprocess_models.py <hrs_ago> [<'1' to reprocess>]"
   print "usage for retros: multiprocess_models.py <startSecs> <endSecs> <1 to reprocess, else 0> <max_fcst_hrs> <exp_name>"

   reprocess = False
   hrs_ago = abs(int(sys.argv[1]))
   print "hrs_ago",hrs_ago
   if hrs_ago > 151121520:  # some time in 1974
       # assume the first arg is 'startSecs' for a retro run
       startSecs = hrs_ago
       endSecs = int(sys.argv[2])
       if sys.argv[3] > 0:
           reprocess = True
       max_fcst_in_hrs = abs(int(sys.argv[4]))
       model = sys.argv[5]
       models = [model]
       run_times = range(startSecs,endSecs,3600)
       print "startSecs",startSecs,"endSecs",endSecs
   else:
       # a regular run
       #models = ['RAP_130','RAP_OPS_130','HRRR_OPS','HRRR']
       models = ['HRRR_GSD']
       run_time1 = time.time()
       # put on hour boundary
       run_time1 -= run_time1 % 3600
       run_time1 -= hrs_ago*3600
       run_times = [run_time1,run_time1-3600,run_time1-3*3600,run_time1-14*3600]
       if len(sys.argv) > 2 and abs(int(sys.argv[2])) > 0:
           reprocess = True
           print "REPROCESSING DATA\n"
     
   stations = []
   f = open("stations.txt","r")
   allLines = f.readlines()
   for line in allLines:
      data = line.split("|")
      id = data[0]
      lat = float(data[1])
      lon = float(data[2])
      elev = float(data[3])
      #print id,lat,lon,elev
      x = Station(id,lat,lon,elev)
      stations.append(x)

   #run_times = [ 1428019200]
   print 'run times ',run_times
   for run_time in run_times:
    run_str = time.strftime("%a, %d %b %Y %H:%M:%S %Z", time.gmtime(run_time))
    print "run time to process: ", run_str

    n_nodes = 12
    manager = Manager()
    ns = manager.Namespace()
    ns.n_good = 0
    jobs = []
    surfrad_start = time.time()
    for model in models:
       print "processing",model
       fcst_inc_minutes = 60
       if model == "WRF_solar":
           # run time is always zero Z for WRF_solar
            if run_time % (24*3600) != 0:
                print "Not at 0Z. no WRF_solar. breaking out. next model"
                continue
            scales = [3,13,26,52]    # scales in km
            max_fcst_in_hrs = 23
            fcst_lens = range(0,max_fcst_in_hrs)
       elif "RAP" in model:
            scales = [13,26,52]    # scales in km
            max_fcst_in_hrs = 21
            fcst_lens = range(0,max_fcst_in_hrs)
       elif "HRRR" in model:
            scales = [3,13,26,52]    # scales in km
            fcst_lens = [0,1,2,3,4,5,6,7,8,9,12,15,18,24,30,36]

       print "fcst_lens",fcst_lens

       # DEBUGGING
       #fcst_lens = [0]
       model_start = time.time()
       nf = 0
       for fcst_len in fcst_lens:
          j = Process(target=process_forecast.go,name=model+"-"+str(fcst_len),
                      args=(ns,reprocess,stations,scales,model,run_time,fcst_len,BAD))
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
   sys.exit(0)

  
                  
                  
                  
