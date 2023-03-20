sub update_summaries_all_nets {
    my($model,$valid_time,$fcst_len,$region,$dbh,$db_name,$DEBUG) = @_;
    use Time::Local;
    use DBI;
    my $vt_str = gmtime($valid_time);
    my $query = "";
    my $sth;
    my $table = "surface_sums.${model}_all_nets_v2_$region";
    my $field_list = "valid_day,hour,fcst_len,N_dt,sum_ob_t,sum_dt,sum2_dt,".
	"N_dw,sum_ob_ws,sum_model_ws,sum_du,sum_dv,sum2_dw,".
	"N_dtd,sum_ob_td,sum_dtd,sum2_dtd,N_drh,sum_ob_rh,sum_drh,sum2_drh";
    my $has_mae=0;
    $query = "describe $table";
    $sth = $dbh->prepare($query);
    $sth->execute();
    while(my $ref = $sth->fetchrow_hashref()) {
	if($ref->{Field} eq "sum_adt") {
	    $has_mae=1;
	    $field_list .= ",sum_adt,sum_adtd";
	    break;
	}
    }
	    
    print "updating $fcst_len h fcst summaries  in $table for $vt_str\n";
    $query =<<"EOI";
replace into $table
($field_list)
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
,sum(if(m.dp is not null,o.dp,null))/10 as sum_ob_dp
,sum(o.dp - m.dp)/10 as sum_dtd
,sum(pow(o.dp - m.dp,2))/100 as sum2_dtd
,count(o.rh - m.rh) as N_drh
,sum(if(m.rh is not null,o.rh,null))/10 as sum_ob_rh
,sum(o.rh - m.rh)/10 as sum_drh
,sum(pow(o.rh - m.rh,2))/100 as sum2_drh
EOI
    if($has_mae) {
	$query .=<<"EOI"
,sum(abs(o.temp - m.temp))/10 as sum_adt
,sum(abs(o.dp - m.dp))/10 as sum_adtd
EOI
}
$query .=<<"EOI"
from $db_name.hr_obs_$valid_time as o
STRAIGHT_JOIN $db_name.${model}qp as m #ignore index (time_id)
STRAIGHT_JOIN $db_name.metars as s
where 1=1
and find_in_set("$region",reg) > 0
and o.sta_id = m.sta_id
and o.sta_id = s.madis_id
and m.fcst_len = $fcst_len
and o.time = m.time
and o.time >= $valid_time - 1800
and o.time < $valid_time + 1800
and  m.temp >-32768  # Xue change this on 20160106 to delete bad model data for NAMnest_OPS_227
#group by valid_day,hour,fcst_len
EOI
    ;
#if($DEBUG) {
#    print "$query";
#}
$dbh->do($query);
}
  1;  
