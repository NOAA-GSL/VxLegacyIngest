# module make_subregion_sums_persis.py
import sys
import time
import MySQLdb
import copy

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
        return str(str(self.hits)+","+str(self.fas)+","+str(self.misss)+","+str(self.crs))

def make_subregion_sums_persis(cursor,valid_time,fcst_lens,accum):

   model = "persis"
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
   model_table = "precip_mesonets2.hourly_pcp2"
   for fcst_len in fcst_lens:
      if accum > 1:
        ob_table = "precip_mesonets2.{accum}h_pcp2_{valid_time}".\
                 format(accum=accum,valid_time=valid_time)
        model_table = "precip_mesonets2.{accum}h_pcp2_{valid_time}".\
                 format(accum=accum,valid_time=valid_time-3600*fcst_len)
      for net in nets:
       # make dictionary prototpye for all threshholds
       CTT = {}
       for thresh in threshs:
         CTT[thresh] = CT(0,0,0,0)
       # make 2D dictionary for [region][thresh]
       CTs = {}
       for region in regions:
         CTs[region] = copy.deepcopy(CTT)
         
       dict = {
          'ob_table': ob_table,
          'model_table' : model_table,
          'model' : model,
          'fcst_len' : fcst_len,
          'valid_time' : valid_time,
          'cutoff' : cutoff,
         }

       query2 = ""
       net_list = ""
       query1="""\
select o.valid_time as valid_time
,{fcst_len} as fcst_len
,loc.reg as reg,
sum(if(        (m.bilin_pcp > 1) and         (o.bilin_pcp > 1),1,0)) as yy1,
sum(if(        (m.bilin_pcp > 1) and NOT (o.bilin_pcp > 1),1,0)) as yn1,
sum(if(NOT (m.bilin_pcp > 1) and         (o.bilin_pcp > 1),1,0)) as ny1,
sum(if(NOT (m.bilin_pcp > 1) and NOT (o.bilin_pcp > 1),1,0)) as nn1,
sum(if(        (m.bilin_pcp > 10) and         (o.bilin_pcp > 10),1,0)) as yy10,
sum(if(        (m.bilin_pcp > 10) and NOT (o.bilin_pcp > 10),1,0)) as yn10,
sum(if(NOT (m.bilin_pcp > 10) and         (o.bilin_pcp > 10),1,0)) as ny10,
sum(if(NOT (m.bilin_pcp > 10) and NOT (o.bilin_pcp > 10),1,0)) as nn10,
sum(if(        (m.bilin_pcp > 25) and         (o.bilin_pcp > 25),1,0)) as yy25,
sum(if(        (m.bilin_pcp > 25) and NOT (o.bilin_pcp > 25),1,0)) as yn25,
sum(if(NOT (m.bilin_pcp > 25) and         (o.bilin_pcp > 25),1,0)) as ny25,
sum(if(NOT (m.bilin_pcp > 25) and NOT (o.bilin_pcp > 25),1,0)) as nn25,
sum(if(        (m.bilin_pcp > 50) and         (o.bilin_pcp > 50),1,0)) as yy50,
sum(if(        (m.bilin_pcp > 50) and NOT (o.bilin_pcp > 50),1,0)) as yn50,
sum(if(NOT (m.bilin_pcp > 50) and         (o.bilin_pcp > 50),1,0)) as ny50,
sum(if(NOT (m.bilin_pcp > 50) and NOT (o.bilin_pcp > 50),1,0)) as nn50,
sum(if(        (m.bilin_pcp > 100) and         (o.bilin_pcp > 100),1,0)) as yy100,
sum(if(        (m.bilin_pcp > 100) and NOT (o.bilin_pcp > 100),1,0)) as yn100,
sum(if(NOT (m.bilin_pcp > 100) and         (o.bilin_pcp > 100),1,0)) as ny100,
sum(if(NOT (m.bilin_pcp > 100) and NOT (o.bilin_pcp > 100),1,0)) as nn100,
sum(if(        (m.bilin_pcp > 150) and         (o.bilin_pcp > 150),1,0)) as yy150,
sum(if(        (m.bilin_pcp > 150) and NOT (o.bilin_pcp > 150),1,0)) as yn150,
sum(if(NOT (m.bilin_pcp > 150) and         (o.bilin_pcp > 150),1,0)) as ny150,
sum(if(NOT (m.bilin_pcp > 150) and NOT (o.bilin_pcp > 150),1,0)) as nn150,
sum(if(        (m.bilin_pcp > 200) and         (o.bilin_pcp > 200),1,0)) as yy200,
sum(if(        (m.bilin_pcp > 200) and NOT (o.bilin_pcp > 200),1,0)) as yn200,
sum(if(NOT (m.bilin_pcp > 200) and         (o.bilin_pcp > 200),1,0)) as ny200,
sum(if(NOT (m.bilin_pcp > 200) and NOT (o.bilin_pcp > 200),1,0)) as nn200
from
{model_table} as m
,{ob_table} as o
,precip_mesonets2.pcp_stations2 as s
,loc_tmp as loc
where 1 = 1
and m.madis_id = o.madis_id
and m.madis_id = s.madis_id
and m.madis_id = loc.madis_id
and o.valid_time - {fcst_len}*3600 = m.valid_time
and o.valid_time = {valid_time}
and o.bilin_pcp < {cutoff}
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
       query3 = "group by o.valid_time,loc.reg"
       query = query1+query2+query3
       #print query
       start_query_secs = time.time()
       try:
          cursor.execute(query)
          for row in cursor.fetchall():
             for region in regions:
                if row.get("reg").find(region) >=0:
                   for thresh in threshs:
                      CTs[region][thresh] += \
                                CT(row["yy"+str(thresh)],row["ny"+str(thresh)],row["yn"+str(thresh)],row["nn"+str(thresh)])
          end_query_secs = time.time()
          query_secs = end_query_secs - start_query_secs
          print "query for net {net} took {secs:.2f} secs".format(net=net,secs=query_secs)
          for reg,v in CTs.items():
              table =  "precip_mesonets2_sums.%s_%s" % (model,reg)
              if accum > 1:
                  table =  "precip_mesonets2_sums.%s_%sh_%s" % (model,accum,reg)
              if net != 'All':
                      table +=  "_%s" % (net)
              values=""
              for k1 in sorted(v.keys()):
                  values +="({valid_time:.0f},{fcst_len},{thresh},{ct}),\n".\
                      format(valid_time=valid_time,fcst_len=fcst_len,thresh=k1,ct=str(v[k1]))
              # remove last comma and cr
              values = values[:-2]
              query="""
replace into {table} (valid_time,fcst_len,thresh,yy,yn,ny,nn)
VALUES\n{values}""".format(values=values,table=table)
              print query
              cursor.execute(query)
              print cursor.rowcount,"rows affected"
                 
       except MySQLdb.Error, e:
          print "Error %d: %s" % (e.args[0], e.args[1])
