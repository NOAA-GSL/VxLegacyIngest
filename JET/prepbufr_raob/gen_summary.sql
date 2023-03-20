select M.date,M.hour,M.fcst_len
,ceil((R.press-20)/50)*5 as mb10
,count(R.t) as N_dt
,sum(R.t - M.t)/100 as sum_dt
,sum(pow(R.t - M.t,2))/100/100 as sum2_dt
, count(distinct R.wmoid) as N_RAOBS
,group_concat(distinct R.wmoid order by R.wmoid) as WMOIDs
,count(R.wd) as N_dw
,sum(R.ws*sin(R.wd/57.2658) -
    M.ws*sin(M.wd/57.2658))/100 as sum_du
,sum(R.ws*cos(R.wd/57.2658) -
     M.ws*cos(M.wd/57.2658))/100 as sum_dv
,sum(pow(R.ws,2)+pow(M.ws,2)- 
        2*R.ws*M.ws*cos((R.wd-M.wd)/57.2958))/
        100/100
   as sum2_dw
,count(R.rh - M.rh) as N_dR
,sum(R.rh - M.rh) as sum_dR
,sum(pow(R.rh - M.rh,2)) as sum2_dR
,sum(R.ws)/100 as sum_ob_ws
,sum(if(R.ws is null,null,M.ws))/100 as sum_model_ws
,count(R.z - M.z) as N_dH
,sum(R.z - M.z) as sum_dH
,sum(pow(R.z - M.z,2)) as sum2_dH
from ruc_ua_pb.rt_ccpp_gsd_L128 as M, ruc_ua_pb.RAOB as R, ruc_ua_pb.metadata as metad
where R.wmoid = metad.wmoid
and R.wmoid = M.wmoid
#and R.wmoid = 29231
and R.date = M.date
and R.hour = M.hour
and R.press = M.press
#and find_in_set(7,reg) > 0
and R.date = '2022-02-07'
and M.date = '2022-02-07'
and R.hour = 0
and M.hour = 0
and M.fcst_len = 0
group by date,hour,mb10,fcst_len
order by N_RAOBS
\G
