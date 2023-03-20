# module make_6h_subregion_sums.py
import sys
import time

def make_6h_subregion_sums(cursor,model,valid_time,fcst_len,ob_table):

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

   # make 6h model table
   model_table = "precip_mesonets2.{model}_6h_{fcst_len}_{valid_time}".\
                 format(model=model,fcst_len=fcst_len,valid_time=valid_time)
   query="drop table if exists "+model_table
   print(query)
   cursor.execute(query)

   query="""\
create temporary  table {model_table} (
  `madis_id` mediumint(8) unsigned NOT NULL COMMENT 'madis_id from madis3 db',
  `valid_time` int(10) unsigned NOT NULL COMMENT 'Valid time, end of ***6h*** accumulation',
  `precip` int(10) unsigned DEFAULT NULL COMMENT 'forecst pcp in SIX hours in hundredths of an inch',
  UNIQUE KEY `time_id` (`valid_time`,`madis_id`),
  UNIQUE KEY `id_time` (`madis_id`,`valid_time`)
)  
select m1.madis_id,m1.valid_time
,m1.precip+m2.precip+m3.precip+m4.precip+m5.precip+m6.precip as precip
from
{model} m1,{model} m2, {model} m3,{model} m4,{model} m5, {model} m6
where 1=1
and m1.madis_id = m2.madis_id
and m1.madis_id = m3.madis_id
and m1.madis_id = m4.madis_id
and m1.madis_id = m5.madis_id
and m1.madis_id = m6.madis_id
and m1.fcst_len = {fcst_len}
and m2.fcst_len = m1.fcst_len - 1
and m3.fcst_len = m1.fcst_len - 2
and m4.fcst_len = m1.fcst_len - 3
and m5.fcst_len = m1.fcst_len - 4
and m6.fcst_len = m1.fcst_len - 5
and m2.valid_time = m1.valid_time - 1*3600
and m3.valid_time = m1.valid_time - 2*3600
and m4.valid_time = m1.valid_time - 3*3600
and m5.valid_time = m1.valid_time - 4*3600
and m6.valid_time = m1.valid_time - 5*3600
and m1.valid_time = {valid_time}
""".format(model=model,model_table=model_table,valid_time=valid_time,fcst_len=fcst_len)
   print(query)
   rows=cursor.execute(query)
   print("%s rows affected"%(rows))

   if rows == 0:
      print("NO MODEL DATA FOR THIS FCST_LEN AND VALID TIME (or 2 hours previous) -- SKIPPING\n")
   else:
      
       threshs = [1,10,25,50,100,150,200]
       regions = ['ALL_HRRR','E_HRRR','W_HRRR','AQPI_LARGE','AQPI_HI','AQPI_LO','AQPI_SIERRA']
       nets = ['All','RAWS','MesoWest','HadsRaws']
       for thresh in threshs:
        for reg in regions:
          for net in nets:
           table =  "precip_mesonets2_sums.%s_6h_%s" % (model,reg)
           if net != 'All':
              table =  "precip_mesonets2_sums.%s_6h_%s_%s" % (model,reg,net)
           dict = {
              'table' : table,
              'model_table' : model_table,
              'ob_table': ob_table,
              'thresh' : thresh,
              'fcst_len' : fcst_len,
              'valid_time' : valid_time,
              'cutoff' : cutoff,
              'reg' : reg
              }

           query2 = ""
           net_list = ""
           query1="""\
replace into {table} (valid_time,fcst_len,thresh,yy,yn,ny,nn)
select m.valid_time,{fcst_len},'{thresh}',
sum(if(        (m.precip > {thresh}) and         (o.bilin_pcp > {thresh}),1,0)) as yy,
sum(if(        (m.precip > {thresh}) and NOT (o.bilin_pcp  > {thresh}),1,0)) as yn,
sum(if(NOT (m.precip > {thresh}) and         (o.bilin_pcp > {thresh}),1,0)) as ny,
sum(if(NOT (m.precip > {thresh}) and NOT (o.bilin_pcp > {thresh}),1,0)) as nn
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
and m.valid_time = {valid_time}
and o.bilin_pcp < 3*{cutoff}
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
           query3 = "group by m.valid_time"
           query = query1+query2+query3
           #print query
           cursor.execute(query)
           print("updated table %s for fcst_len %s, thresh %s ... %s rows affected"%\
                 (table,fcst_len,thresh,cursor.rowcount))
