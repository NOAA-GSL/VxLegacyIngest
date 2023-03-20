use soundings;

select wmoid,count(*) as N,group_concat(mean_h_diff) as diffs
from hypsometric_summary
#where wmoid=72469
group by wmoid
having N > 0
order by wmoid;
