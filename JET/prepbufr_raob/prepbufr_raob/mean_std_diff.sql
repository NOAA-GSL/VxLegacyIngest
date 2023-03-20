use soundings_pb;
select hs.wmoid,name,descript,count(*) as N
,round(avg(mean_h_diff_500)/10,1) as avg500
,round(std(mean_h_diff_500)/10,1) as std500
,round(abs(avg(mean_h_diff_500))/std(mean_h_diff_500),1) r
,round(avg(mean_h_diff)/10,1) as avg1
,round(std(mean_h_diff)/10,1) as std1
from hypsometric_summary hs, ruc_ua_pb.metadata m
where 1=1
and hs.wmoid = m.wmoid
#and hs.wmoid = 89664
and n_h_diff_500 > 0
and time >= 1646870400  # Thu 10 Mar 2022 00:00:00
group by wmoid
having N > 8
order by abs(avg(mean_h_diff_500))/std(mean_h_diff_500);

