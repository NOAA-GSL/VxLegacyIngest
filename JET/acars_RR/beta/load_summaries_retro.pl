sub load_summaries_retro {
    my($dbh,$model,$fcst_len,$min_date,$max_date,$up_dn) = @_;
    my @regions= qw(Full HRRR);
    if($model =~ /^HRRR/) {
	@regions = qw(Full);
    }
    foreach my $region (@regions) {
    my $table = "${model}_${fcst_len}_${region}_sums";
    my $up_dn_test = "and up_dn = $up_dn";
    my $up_dn_string = ",'$up_dn' as up_dn";
    my $table_string = "(acars_retro as o use index (date),${model}_$fcst_len as m) left join retro_rejects rj on o.xid = rj.xid";
    my $match_string = "and o.aid = m.aid";
    if($region eq "HRRR") {
	$match_string.= " and o.source = 1"; # in HRRR region
    }
    if($up_dn == 0) {
	$up_dn_test = "and up_dn is null";
	$up_dn_string = ",'0' as up_dn";
    } elsif($up_dn == 2) {	# all phases of flight
	$up_dn_test = " # (accept all values of up_dn)";
	$up_dn_string = ",'$up_dn' as up_dn";
    }
    my $model_table = "${model}_$fcst_len";
my  $query=<<"EOI"
replace into $table (date,hour,up_dn,mb10,N_dt,sum_ob_t,sum_dt,sum2_dt,N_dw,sum_ob_ws,
sum_model_ws,sum_du,sum_dv,sum2_dw,N_dR,sum_ob_R,sum_dR,sum2_dR)
# describe
select
date(date_add(date, interval 30 minute)) as date2 # dont confuse the group-by with 'date'
,hour(date_add(date, interval 30 minute)) as hour2
$up_dn_string
,floor((press-250)/500)*5+5 as mb10
,sum(if(rj.bad_T = 'T' or t is null, 0,1)) as N_dt
,sum(if(rj.bad_T = 'T',0,t))/100 as sum_ob_t
,sum(if(rj.bad_T = 'T',0,t - m.tf))/100 as sum_dt
,sum(if(rj.bad_T = 'T',0,pow(t - m.tf,2)))/100/100 as sum2_dt
,sum(if(rj.bad_W = 'W' or dir is null, 0,1)) as N_dw
,sum(if(rj.bad_W = 'W' or dir is null,0, s))/100 as sum_ob_ws
,sum(if(rj.bad_W = 'W' or dir is null,0, m.sf))/100 as sum_model_ws
,sum(if(rj.bad_W = 'W' or dir is null,
             0,s*sin(dir/5726.58) - m.sf*sin(m.dirf/5726.58))
	     )/100 as sum_du
,sum(if(rj.bad_W = 'W' or dir is null,
             0,s*cos(dir/5726.58) - m.sf*cos(m.dirf/5726.58))
	     )/100 as sum_dv
,sum(if(rj.bad_W = 'W' or dir is null,
             0,pow(s,2)+pow(m.sf,2)- 2*s*m.sf*cos((dir-m.dirf)/5729.58))
	     )/10000 as sum2_dw
,sum(if(rj.bad_RH = 'R' or rh is null,0, 1)) as N_dR
,sum(if(rj.bad_RH = 'R', 0,rh)) as sum_ob_R
,sum(if(rj.bad_RH = 'R', 0,rh - m.rhf)) as sum_dR
,sum(if(rj.bad_RH = 'R', 0,pow(rh - m.rhf,2))) as sum2_dR
from $table_string
where 1=1
$match_string
$up_dn_test
and o.date >= '$min_date'
and o.date <= '$max_date'
group by date2,hour2,mb10
order by date2,hour2,mb10
EOI
;   
print "$query";
$rows = $dbh->do($query); 
print_warn($dbh);
print "$rows rows affected\n\n";
     }}

     1;
     
    
