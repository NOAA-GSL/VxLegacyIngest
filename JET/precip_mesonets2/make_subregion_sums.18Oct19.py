# module make_subregion_sums.py
import sys
import time
import MySQLdb

def make_subregion_sums(cursor,model,valid_time,fcst_len,accum):

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
     cursor.execute(query)
     cutoff = cursor.fetchone()['cutoff']

   cutoff = 1500 # John B says 15 inches/hr is a reasonable cutoff
                        # But Janice Bythway says 2"/hr is the psbl outlier value used by MRMS
   query="""\
select count(*) as N
from precip_mesonets2.hourly_pcp2 as o
where 1 = 1
and valid_time = %s
and bilin_pcp > %s
""" % (valid_time,cutoff)
   cursor.execute(query)
   N_out = cursor.fetchone()['N']

   valid_str = time.strftime("%a, %d %b %Y %H:%M:%S %Z", time.gmtime(valid_time))
   print N_out,'obs exceed cutoff of',cutoff, "for", valid_str
          
   threshs = [1,10,25,50,100,150,200]
   regions = ['ALL_HRRR','E_HRRR','W_HRRR','AQPI_LARGE','AQPI_HI','AQPI_LO','AQPI_SIERRA']
   nets = ['All','RAWS','MesoWest','HadsRaws']
   ob_table = "precip_mesonets2.hourly_pcp2"
   if accum == 3:
      ob_table = "precip_mesonets2.3h_pcp2_{valid_time}".format(valid_time=valid_time)
   for thresh in threshs:
    for reg in regions:
      for net in nets:
       table =  "precip_mesonets2_sums.%s_%s" % (model,reg)
       if accum == 3:
          table =  "precip_mesonets2_sums.%s_3h_%s" % (model,reg)
       if net != 'All':
          table +=  "_%s" % (net)
       dict = {
          'table' : table,
          'thresh' : thresh,
          'model' : model,
          'fcst_len' : fcst_len,
          'valid_time' : valid_time,
          'cutoff' : cutoff,
          'reg' : reg,
          'ob_table': ob_table
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
,{ob_table} as o
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
       #print query
       print "updating",table,"for thresh",thresh,"...",
       try:
          cursor.execute(query)
          print cursor.rowcount,"rows affected"
       except MySQLdb.Error, e:
          print "Error %d: %s" % (e.args[0], e.args[1])
