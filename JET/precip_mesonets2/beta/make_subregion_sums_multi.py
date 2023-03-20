# module make_subregion_sums.py
import sys
import time
from string import *
from multiprocessing import Process, Pipe,Manager
import process_net

def make_subregion_sums(cursor_dict,model,valid_time,fcst_len):

   # turn off variable cutoff for now
   if None:
     query="""\
select avg(bilin_pcp)+3.*std(bilin_pcp) as cutoff
from precip_mesonets2.hourly_pcp2 as o
where 1 = 1
and valid_time = %s
group by valid_time
""" % (valid_time)
    #print query
     cursor_dict['All'].execute(query)
     cutoff = cursor_dict['All'].fetchone()['cutoff']

   cutoff = 1500 # John B says 15 inches/hr is a reasonable cutoff
                        # But Janice Bythway says 2"/hr is the psbl outlier value used by MRMS
   query="""\
select count(*) as N
from precip_mesonets2.hourly_pcp2 as o
where 1 = 1
and valid_time = %s
and bilin_pcp > %s
""" % (valid_time,cutoff)
   cursor_dict['All'].execute(query)
   N_out = cursor_dict['All'].fetchone()['N']

   valid_str = time.strftime("%a, %d %b %Y %H:%M:%S %Z", time.gmtime(valid_time))
   print N_out,'obs exceed cutoff of',cutoff, "for", valid_str
          
   nets = ['All','RAWS','MesoWest','HadsRaws']
   regions = ['ALL_HRRR','E_HRRR','W_HRRR','AQPI_LARGE','AQPI_HI','AQPI_LO','AQPI_SIERRA']

   manager = Manager()
   ns = manager.Namespace()
   ns.n_good = 0
   jobs = []
   n_nodes = 1
   n_nets_regions=0  
   for net in nets:
    for reg in regions:
     j = Process(target=process_net.go, name=model+"-"+net+"-"+reg,
                 args=(cursor_dict,net,reg,model,valid_time,fcst_len,cutoff))
     j.start()
     pid = j.pid
     jobs.append((j,pid))
     n_nets_regions += 1
     if n_nets_regions%n_nodes == 0 or n_nets_regions == len(nets)*len(regions):
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
