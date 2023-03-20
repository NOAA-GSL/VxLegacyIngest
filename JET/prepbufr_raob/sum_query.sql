select mdl.date,mdl.hour,mdl.fcst_len
,count(R.t) as N_dt
from ruc_ua_pb.rt_ccpp_gsd_L128 as mdl, ruc_ua_pb.RAOB as R, ruc_ua_pb.metadata as m
where R.wmoid = m.wmoid
and R.wmoid = mdl.wmoid
and R.date = mdl.date
and R.hour = mdl.hour
and R.press = mdl.press
and find_in_set(7,reg) > 0
and R.date = '2022-02-04'
and mdl.date = '2022-02-04'
and R.press = 500
and R.hour = 0
and mdl.hour = 0
and mdl.fcst_len = 0
group by date,hour,mb10,fcst_len;

select count(wmoid) from ruc_ua_pb.rt_ccpp_gsd_L128 as mdl #,ruc_ua_pb.RAOB as R
where 1=1
#and R.date = '2022-02-04'
#and R.press = 500
#and R.hour = 0;
and mdl.date = '2022-02-04'
and mdl.hour = 0
and mdl.press = 500
;
select distinct wmoid from ruc_ua_pb.rt_ccpp_gsd_L128 ;
