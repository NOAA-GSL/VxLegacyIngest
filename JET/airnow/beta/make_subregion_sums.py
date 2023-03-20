# module make_subregion_sums.py
import sys
import time

def make_subregion_sums(cursor,model,valid_time,fcst_len):

   cutoff = 1e20  # ignore this for now
   
   query="""\
select count(*) as N
from airnow.obs2p5 as o
where 1 = 1
and time = %s
and pm2p5_10 > %s
""" % (valid_time,cutoff*10)
   cursor.execute(query)
   N_out = cursor.fetchone()['N']

   valid_str = time.strftime("%a, %d %b %Y %H:%M:%S %Z", time.gmtime(valid_time))
   print N_out,'obs exceed cutoff of',cutoff, "for", valid_str
          
   threshs_10 = [300,600,1000,1500]  # in ug/m^3 * 10
   regions = ['ALL_HRRR','E_HRRR','W_HRRR','NW_CONUS']
   scales = [3,13,26,52]    # scales in km
   for thresh_10 in threshs_10:
    for reg in regions:
      for scale in scales:
       table =  "airnow_sums.%s_%s" % (model,reg)
       dict = {
          'table' : table,
          'thresh_10' : thresh_10,
          'scale': scale,
          'model' : model,
          'fcst_len' : fcst_len,
          'valid_time' : valid_time,
          'cutoff' : cutoff,
          'reg' : reg
          }

       query2 = ""
       query1="""\
replace into {table} (valid_time,fcst_len,thresh_10,scale,yy,yn,ny,nn)
select m.time,m.fcst_len,'{thresh_10}','{scale}',
sum(if(        (m.pm2p5_10 > {thresh_10}) and         (o.pm2p5_10 > {thresh_10}),1,0)) as yy,
sum(if(        (m.pm2p5_10 > {thresh_10}) and NOT (o.pm2p5_10 > {thresh_10}),1,0)) as yn,
sum(if(NOT (m.pm2p5_10 > {thresh_10}) and         (o.pm2p5_10 > {thresh_10}),1,0)) as ny,
sum(if(NOT (m.pm2p5_10 > {thresh_10}) and NOT (o.pm2p5_10 > {thresh_10}),1,0)) as nn
from
airnow.{model} as m
,airnow.obs2p5 as o
,airnow.stations as s
where 1 = 1
and m.id = o.id
and m.id = s.id
and m.time = o.time
and m.time = {valid_time}
and m.fcst_len = {fcst_len}
and m.scale = {scale}
and m.pm2p5_10 > 20     # !!! iGNORE SITES WHERE MODEL PM2.5 <= 2.0 UG/M^3 !!!
and find_in_set('{reg}',s.reg) > 0
""".format(**dict)
       query3 = "group by m.time,m.fcst_len,m.scale"
       query = query1+query2+query3
       print "updating",table,"for thresh_10",thresh_10
       print query
       cursor.execute(query)
       print cursor.rowcount,"rows affected\n"
