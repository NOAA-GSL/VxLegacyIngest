#!/usr/bin/env python
import os
import sys
import time
import MySQLdb
import copy
import MySQLdb.cursors
import warnings

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
        
def processed(cursor,model,region,valid_time,fcst_len):
    query="""\
select count(*) as N
from precip_mesonets2_sums.{model}_{region}
where 1=1
and valid_time = {valid_time}
and fcst_len = {fcst_len}
""".format(model=model,region=region,valid_time=valid_time,fcst_len = fcst_len)
    cursor.execute(query)
    N = cursor.fetchone()['N']
    if N > 0:
        return(True)
    else:
        return(False)
       
def make_subregion_sums3(cursor,model,regions,valid_time,fcst_len,accum):
   warnings.filterwarnings("ignore", category = MySQLdb.Warning)
   start_secs = time.time()
   # return quick if no forecasts
   query="""\
select count(*) as N from {model} m
where 1=1
and m.fcst_len = {fcst_len}
and m.valid_time = {valid_time}
   """.format(fcst_len=fcst_len,valid_time=valid_time,model=model)
   #print(query)
   cursor.execute(query)
   N_out = cursor.fetchone()['N']
   if N_out == 0:
       print "No model data for {model} {fcst_len}h fcst valid {vt_str}".\
       format(fcst_len=fcst_len,model=model,\
              vt_str = time.strftime("%a, %d %b %Y %H:%M:%S %Z", time.gmtime(valid_time)))
       return()
  
   nets = ['All','RAWS','MesoWest','HadsRaws']
   threshs = [1,10,25,50,100,150,200]

   cutoff =  256 # 2.56" seems to be a good cutoff per
         #https://docs.google.com/spreadsheets/d/1QU4hhJ-btZkTOeDIuVAOSzYnQ5NlymVoEGJePGdtilE/edit#gid=0
   query="""\
select count(*) as N
from precip_mesonets2.hourly_pcp2 as o
where 1 = 1
and valid_time = %s
and bilin_pcp > %s
""" % (valid_time,cutoff)
   #cursor.execute(query)
   #N_out = cursor.fetchone()['N']
   #valid_str = time.strftime("%a, %d %b %Y %H:%M:%S %Z", time.gmtime(valid_time))
   #print N_out,'obs exceed cutoff of',cutoff, "for", valid_str
  
   ob_table = "precip_mesonets2.hourly_pcp2"
   model_table = "precip_mesonets2.{model}".format(model=model)
   for fcst_len in [fcst_len]:  # this loop no longer needed--process just one forecast
    #print "gen locations for this run_time/valid time"
    # get id's of all stations that do not change location during the window
    # between the run time (when the locations were used in the model table)
    # and the valid_time (when the locations were used in the obs table)
    query_start_secs=time.time()
    query = "drop table if exists moving_stations"
    cursor.execute(query)
    query="""\
 create temporary table moving_stations
(madis_id mediumint unsigned not null primary key)
select madis_id #,count(*) as N
from locations2 loc
where 
first_time <= {valid_time}
and first_time >= {run_time}
group by madis_id
having count(*) > 0
""".format(valid_time=valid_time,run_time = valid_time-3600*fcst_len)
    cursor.execute(query)
    if cursor.rowcount > 0:
        print("not using {rows} stations that changed their locations in the {fcst_len} hours between anx and valid time.".\
              format(rows=cursor.rowcount,fcst_len=fcst_len))
    query = "drop table if exists loc_tmp"
    cursor.execute(query)
    query="""\
create  table loc_tmp (
`madis_id` mediumint(8) unsigned NOT NULL primary key COMMENT 'id from madis3 database',
`first_time` int(10) unsigned NOT NULL COMMENT 'time this location was first seen for this station',
`reg` set('ALL_RUC','E_RUC','W_RUC','ALL_HRRR','E_HRRR','W_HRRR','ALL_RR1','ALL_RR2','AK',\
    'HWT','STMAS_CI',\
    'Global','NHX','SHX','TRO','NHX_E','NHX_W','C','S','SE','N','NE','HI',\
    'AQPI_LARGE','AQPI_HI','AQPI_LO','AQPI_SIERRA') DEFAULT 'Global'
)
select loc.madis_id,first_time,reg
from locations2 loc left join moving_stations ms
         on (loc.madis_id = ms.madis_id)
where
 first_time =
    (select first_time from locations2 loc2
     where loc2.first_time <= %s
     and loc2.madis_id = loc.madis_id
     order by first_time desc limit 1)
and  ms.madis_id is null   
    """ % (valid_time)
    #print query
    cursor.execute(query)
    query_end_secs=time.time()
    query_secs = query_end_secs - query_start_secs
    #print cursor.rowcount,"rows affected in ",query_secs," secs"
      
    if accum > 1:
        ob_table = "precip_mesonets2.{accum}h_pcp2_{valid_time}".\
                 format(accum=accum,valid_time=valid_time)
        model_table += "_{accum}h".format(accum=accum)
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
sum(if(        (m.precip > 1) and           (o.bilin_pcp > 1),1,0)) as yy1,
sum(if(        (m.precip > 1) and  NOT  (o.bilin_pcp > 1),1,0)) as yn1,
sum(if(NOT (m.precip > 1) and           (o.bilin_pcp > 1),1,0)) as ny1,
sum(if(NOT (m.precip > 1) and  NOT  (o.bilin_pcp > 1),1,0)) as nn1,
sum(if(        (m.precip > 10) and         (o.bilin_pcp > 10),1,0)) as yy10,
sum(if(        (m.precip > 10) and NOT (o.bilin_pcp > 10),1,0)) as yn10,
sum(if(NOT (m.precip > 10) and         (o.bilin_pcp > 10),1,0)) as ny10,
sum(if(NOT (m.precip > 10) and NOT (o.bilin_pcp > 10),1,0)) as nn10,
sum(if(        (m.precip > 25) and         (o.bilin_pcp > 25),1,0)) as yy25,
sum(if(        (m.precip > 25) and NOT (o.bilin_pcp > 25),1,0)) as yn25,
sum(if(NOT (m.precip > 25) and         (o.bilin_pcp > 25),1,0)) as ny25,
sum(if(NOT (m.precip > 25) and NOT (o.bilin_pcp > 25),1,0)) as nn25,
sum(if(        (m.precip > 50) and         (o.bilin_pcp > 50),1,0)) as yy50,
sum(if(        (m.precip > 50) and NOT (o.bilin_pcp > 50),1,0)) as yn50,
sum(if(NOT (m.precip > 50) and         (o.bilin_pcp > 50),1,0)) as ny50,
sum(if(NOT (m.precip > 50) and NOT (o.bilin_pcp > 50),1,0)) as nn50,
sum(if(        (m.precip > 100) and         (o.bilin_pcp > 100),1,0)) as yy100,
sum(if(        (m.precip > 100) and NOT (o.bilin_pcp > 100),1,0)) as yn100,
sum(if(NOT (m.precip > 100) and         (o.bilin_pcp > 100),1,0)) as ny100,
sum(if(NOT (m.precip > 100) and NOT (o.bilin_pcp > 100),1,0)) as nn100,
sum(if(        (m.precip > 150) and         (o.bilin_pcp > 150),1,0)) as yy150,
sum(if(        (m.precip > 150) and NOT (o.bilin_pcp > 150),1,0)) as yn150,
sum(if(NOT (m.precip > 150) and         (o.bilin_pcp > 150),1,0)) as ny150,
sum(if(NOT (m.precip > 150) and NOT (o.bilin_pcp > 150),1,0)) as nn150,
sum(if(        (m.precip > 200) and         (o.bilin_pcp > 200),1,0)) as yy200,
sum(if(        (m.precip > 200) and NOT (o.bilin_pcp > 200),1,0)) as yn200,
sum(if(NOT (m.precip > 200) and         (o.bilin_pcp > 200),1,0)) as ny200,
sum(if(NOT (m.precip > 200) and NOT (o.bilin_pcp > 200),1,0)) as nn200
from
{model_table} as m
,{ob_table} as o
,precip_mesonets2.pcp_stations2 as s
,loc_tmp as loc
where 1 = 1
and m.madis_id = o.madis_id
and m.madis_id = s.madis_id
and m.madis_id = loc.madis_id
and m.valid_time = o.valid_time
and m.fcst_len = {fcst_len}
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
          if cursor.rowcount == 0:
              print "no data!"
              continue
          for row in cursor.fetchall():
             for region in regions:
                if row.get("reg").find(region) >=0:
                   for thresh in threshs:
                      CTs[region][thresh] += \
                                CT(row["yy"+str(thresh)],row["ny"+\
                                                             str(thresh)],row["yn"+str(thresh)],row["nn"+str(thresh)])
          end_query_secs = time.time()
          query_secs = end_query_secs - start_query_secs
          #print "query for net {net} took {secs:.2f} secs".format(net=net,secs=query_secs)
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
              #print query
              cursor.execute(query)
              #print cursor.rowcount,"rows affected"
       except MySQLdb.Error, e:
          print "Error %d: %s" % (e.args[0], e.args[1])
   end_secs = time.time()
   tot_secs = end_secs - start_secs
   print "{tot_secs:.1f} seconds to process {fcst_len}h {model} fcst valid {vt_str}".\
       format(tot_secs=tot_secs,fcst_len=fcst_len,model=model,\
              vt_str = time.strftime("%a, %d %b %Y %H:%M:%S %Z", time.gmtime(valid_time)))

