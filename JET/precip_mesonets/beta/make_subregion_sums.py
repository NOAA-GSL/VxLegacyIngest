# module make_subregion_sums.py

def make_subregion_sums(cursor,model,valid_time,fcst_len):
   threshs = [1,10,25,50,100,150,200]
   regions = ['ALL_HRRR','E_HRRR','W_HRRR']
   for thresh in threshs:
    for reg in regions:
       table =  "precip_mesonets_sums.%s_%s" % (model,reg)
       query="""\
replace into %s (valid_time,fcst_len,thresh,yy,yn,ny,nn)
select m.valid_time,m.fcst_len,'%s',
sum(if(    (m.precip > %s) and     (o.bilin_pcp > %s),1,0)) as yy,
sum(if(    (m.precip > %s) and NOT (o.bilin_pcp > %s),1,0)) as yn,
sum(if(NOT (m.precip > %s) and     (o.bilin_pcp > %s),1,0)) as ny,
sum(if(NOT (m.precip > %s) and NOT (o.bilin_pcp > %s),1,0)) as nn
from
precip_mesonets.%s as m,precip_mesonets.hourly_pcp as o,precip_mesonets.pcp_stations as s
where 1 = 1
and m.madis_id = o.madis_id
and m.madis_id = s.madis_id
and m.valid_time = o.valid_time
and m.fcst_len = %s
and m.valid_time = %s
and find_in_set('%s',s.reg) > 0
group by m.valid_time,m.fcst_len
""" % (table,thresh,thresh,thresh,thresh,thresh,thresh,thresh,thresh,thresh,model,fcst_len,valid_time,reg)

       #print query
       print "updating",table,"..",
       cursor.execute(query)
       print cursor.rowcount,"rows affected\n"
       #print "warnings (if any):",cursor.fetchwarnings()
