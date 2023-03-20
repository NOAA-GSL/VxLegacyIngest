def update_summaries3 (data_source,valid_time,fcst_len,region,cursor,db_name,DEBUG):

    import os
    import sys
    import MySQLdb
    from string import *


    table = "surface_sums."+data_source+"_"+str(fcst_len)+"_metar_"+region
    print "nupdating summaries in "+table
    query ="""
    replace into """+table+""" 
    (valid_day,hour,fcst_len,N_dt,sum_ob_t,sum_dt,sum2_dt,
    N_dw,sum_ob_ws,sum_model_ws,sum_du,sum_dv,sum2_dw,
    N_dtd,sum_ob_td,sum_dtd,sum2_dtd)
    select floor((m.time+1800)/(24*3600))*(24*3600) as valid_day
    ,floor(((m.time+1800)%(24*3600))/3600) as hour
    ,m.fcst_len
    ,count(o.temp - m.temp) as N_dt
    ,sum(if(m.temp is not null,o.temp,null))/10 as sum_ob_t
    ,sum(o.temp - m.temp)/10 as sum_dt
    ,sum(pow(o.temp - m.temp,2))/100 as sum2_dt
    ,count(o.wd + m.wd) as N_dw
    ,sum(if(m.ws is not null,o.ws,null)) as sum_ob_ws
    ,sum(if(o.ws is not null,m.ws,null)) as sum_model_ws
    ,sum(o.ws*sin(o.wd/57.2658) - m.ws*sin(m.wd/57.2658)) as sum_du
    ,sum(o.ws*cos(o.wd/57.2658) - m.ws*cos(m.wd/57.2658)) as sum_dv
    ,sum(pow(o.ws,2)+pow(m.ws,2)-  2*o.ws*m.ws*cos((o.wd-m.wd)/57.2958)) as sum2_dw
    ,count(o.dp - m.dp) as N_dtd
    ,sum(if(m.dp is not null,o.dp,null))/10 as avg_ob_dp
    ,sum(o.dp - m.dp)/10 as sum_dtd
    ,sum(pow(o.dp - m.dp,2))/100 as sum2_dtd
    from madis3.obs as o,madis3."""+data_source+"""a as m,madis3.metars as s
    where 1=1
    and find_in_set('"""+region+"',"+"""reg) > 0
    and o.sta_id = m.sta_id
    and o.sta_id = s.madis_id
    and m.fcst_len = """+str(fcst_len)+""" 
    and o.time = m.time
    and o.time >= """+str(int(valid_time))+""" - 1800
    and o.time < """+str(int(valid_time))+""" + 1800
    group by valid_day,hour,fcst_len
    """

    if DEBUG:
        print query
    
    cursor.execute(query)

