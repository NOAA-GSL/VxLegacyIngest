#!/lfs1/projects/amb-verif/anaconda3/bin/python3
import sys
import os
from string import *
from random import *
from statistics import *
import numpy as np
import time
from math import *
import pymysql

class CT:
    """A Contingency Table"""
    def __init__(self,hits,misss,fas,crs):
        self.hits = hits
        self.misss = misss
        self.fas = fas
        self.crs = crs
    def __add__(a,b):
        return CT(a.hits+b.hits,a.misss+b.misss,a.fas+b.fas,a.crs+b.crs)
    def __str__(self):
        return str("hits: "+str(self.hits)+", misss:"+str(self.misss)+\
                   ", fas: "+str(self.fas)+", crs: "+str(self.crs))

def get_csis(cts,permutation=True):
    ct = [CT(0,0,0,0),CT(0,0,0,0)]
    for i in range(0,len(cts)): # loop over cts
      if permutation == True:
          # assume seeding of the random number generator is done first
          j = randrange(0,2)    # randomly permute between the two result sets
      else:
          j=0                   # no permutation
      ct[0] = ct[0]+cts[i][j]
      ct[1] = ct[1]+cts[i][1-j]
    csi0 = ct[0].hits/float(ct[0].hits+ct[0].misss+ct[0].fas)
    csi1 = ct[1].hits/float(ct[1].hits+ct[1].misss+ct[1].fas)
    return(csi0,csi1)

 # main program
if __name__== '__main__':
   os.environ['PYTHONUNBUFFERED'] = str(1)
   start_secs = time.time()

   overall = []
   cts = []
   model = "HRRR_OPS_GSD"  # contains HRRR_OPS followed by HRRR_GSD
   fcst_len=2
   input_file = "%s_AQPI_LARGE_%d.txt"%(model,fcst_len)
   print("input file: %s"%(input_file))
   try:
       f = open(input_file,"r")
   except:
       print("%s not found!" % (input_file))
       sys.exit(0)
   allLines = f.readlines()
   
   i=-1
   for line in allLines:
      data = line.split("\t")
      if data[0] == 'avtime':
          continue              # avoid header line
      hits0 = int(data[2])
      fas0 = int(data[3])
      misss0 = int(data[4])
      crs0 = int(data[5].rstrip())
      hits1 = int(data[6])
      fas1 = int(data[7])
      misss1 = int(data[8])
      crs1 = int(data[9].rstrip())
      cts.append([CT(hits0,misss0,fas0,crs0),CT(hits1,misss1,fas1,crs1)])
      i += 1
      #print("%d GSD: %s / OPS: %s\n"%(i,cts[i][0],cts[i][1]))

   (csi0,csi1) = get_csis(cts,permutation=False)
   print("csis for 2h forecasts: GSD: %.3f, OPS: %.3f, diff: %+.3f" % (csi0,csi1,csi0-csi1))

   seed()                       # initialize random number generator used in get_csis
   csi_diffs = []
   trys = 1000
   for instance in range(0,trys):     # loop over bootstrap attempts
       (csi0,csi1) = get_csis(cts,permutation=True)
       csi_diffs.append(csi0-csi1)
   avg_diff = mean(csi_diffs)
   print("%d trys: mean_diff: %.6f, min: %.3f, max: %.3f, std*1.98: %.6f" % \
         (trys,avg_diff,min(csi_diffs),max(csi_diffs),1.98*stdev(csi_diffs)))
   csi_diffs.sort()                  # sort the list of CSI's
   csi_low = csi_diffs[0]
   csi_hi = csi_diffs[trys-1]
   i_min = floor(trys*0.025)
   i_max = ceil((trys-1)*0.975)
   bot_95 = csi_diffs[i_min]
   top_95 = csi_diffs[i_max]
   print("95 bottom: %.3f, 95 top: %.3f" %(bot_95,top_95))
   print("mean-bottom: %.3f, top-mean: %.3f" % (avg_diff-bot_95,top_95-avg_diff))

   # poor man's histogram
   count = [0]*21
   max_count=0
   bin_width = (csi_hi - csi_low)/20
   for csi in csi_diffs:
       bin_number = floor((csi - csi_low)/bin_width)
       #print("%.3f, %d"%(csi,bin_number))
       count[bin_number] += 1
       if count[bin_number] > max_count:
           max_count = count[bin_number]

   scale = ceil(max_count/80)
   for bin in range(0,21):
       line = "%+5.3f => %03d " % (csi_low+bin*bin_width,count[bin]) + '*'*ceil(count[bin]/scale)
       print(line)
   
