use ruc_ua_pb;
select m.press
,m.height-w.height as h_diff
#,m.temp-w.temp as t_diff
from hypso m, uwyo w
where 1=1
and m.press = w.press
#order by abs(m.height-w.height)
order by m.press desc
;
