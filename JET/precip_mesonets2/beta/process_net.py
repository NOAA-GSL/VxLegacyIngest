import sys
import os
from string import *
from numpy import *
#import math
import time
import multiprocessing

def go(cursor_dict,net,reg,model,valid_time,fcst_len,cutoff):
    start_secs = time.time()
    current = multiprocessing.current_process()
    current.name = str(__name__)
    pid = os.getpid()
    threshs = [1,10,25,50,100,150,200]
    cursor = cursor_dict[net]
    table =  "precip_mesonets2_sums.%s_%s" % (model,reg)
    if net != 'All':
          table =  "precip_mesonets2_sums.%s_%s_%s" % (model,reg,net)
    for thresh in threshs:
       dict = {
          'table' : table,
          'thresh' : thresh,
          'model' : model,
          'fcst_len' : fcst_len,
          'valid_time' : valid_time,
          'cutoff' : cutoff,
          'reg' : reg
          }
       query2 = ""
       net_list = ""
       query1="""\
replace into {table} (valid_time,fcst_len,thresh,yy,yn,ny,nn)
select m.valid_time,m.fcst_len,'{thresh}',
sum(if(        (m.precip > {thresh}) and         (o.bilin_pcp > {thresh}),1,0)) as yy,
sum(if(        (m.precip > {thresh}) and NOT (o.bilin_pcp > {thresh}),1,0)) as yn,
sum(if(NOT (m.precip > {thresh}) and         (o.bilin_pcp > {thresh}),1,0)) as ny,
sum(if(NOT (m.precip > {thresh}) and NOT (o.bilin_pcp > {thresh}),1,0)) as nn
from
precip_mesonets2.{model} as m
,precip_mesonets2.hourly_pcp2 as o
,precip_mesonets2.pcp_stations2 as s
,loc_tmp as loc
where 1 = 1
and m.madis_id = o.madis_id
and m.madis_id = s.madis_id
and m.madis_id = loc.madis_id
and m.valid_time = o.valid_time
and m.fcst_len = {fcst_len}
and m.valid_time = {valid_time}
and o.bilin_pcp < {cutoff}
and find_in_set('{reg}',loc.reg) > 0
""".format(**dict)
       if net != 'All':
          if net == 'MesoWest':
             net_list = "'MesoWest'"
          elif net == 'HadsRaws':
             net_list = "'HADS','RAWS'"
          elif net == 'RAWS':
             net_list = "'RAWS'"
          query2="""\
and s.net IN({net_list})
""".format(net_list=net_list)
       query3 = "group by m.valid_time,m.fcst_len"
       query = query1+query2+query3
       cursor.execute(query)
       print pid," updating",table,"for thresh",thresh,"...",cursor.rowcount,"rows affected"
    end_secs = time.time()
    proc_secs = end_secs - start_secs
    sys.exit(int(proc_secs))
