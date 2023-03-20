use strict;
sub update_summaries_v3u_new {
    # this version uses only METARs that are on the uselist!!!
    my($model,$valid_time,$fcst_len,$region,$dbh,$db_name,$DEBUG) = @_;
    use Time::Local;
    use DBI;
    $USELIST_TABLE = "rap_ops_uselist";
    my $vt_str = gmtime($valid_time);
    my $query = "";
    my $sth;
    $dbh->do("use madis3");
    my @bad_ids;
    $query =<<"EOI"
select sta_id
from bad_obs_for_summaries
where 1=1
and (first_bad_time is  null or $valid_time >= first_bad_time)
and (last_bad_time is  null or $valid_time <= last_bad_time)
EOI
;
    #print "$query;\n";
    $sth = $dbh->prepare($query);
    $sth->execute();
    my($bad_id);
    $sth->bind_columns(\$bad_id);
    while($sth->fetch()) {
	push(@bad_ids,$bad_id);
    }
    my $bad_id_string = "";
    if(@bad_ids >0) {
	my $bad_ids = join(',',@bad_ids);
	$bad_id_string = "and o.sta_id not in($bad_ids)";
    }
    $dbh->do("use surface_sums2");
    my $table = "${model}_metar_v3u_$region";
    $query = qq{show tables like "$table"};
    #print "$query\n";
    my @result = $dbh->selectrow_array($query);
    #print "result is |@result|\n";
    unless(@result) {
       $query = "create table $table like template";
       $dbh->do($query);
    }
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
	    last;
	}
    }
	    
    print "updating ${fcst_len}h fcst sums in surface_sums2.$table for $vt_str";
    $query =<<"EOI";
replace into $table
($field_list)
select floor((m.time+1800)/(24*3600))*(24*3600) as valid_day
,floor(((m.time+1800)%(24*3600))/3600) as hour
,m.fcst_len
,count(if(u.T_flag = 1, o.temp - m.temp,null)) as N_dt
,sum(if(u.T_flag = 1 and m.temp is not null,o.temp,null))/10 as sum_ob_t
,sum(if(u.T_flag = 1, o.temp - m.temp,null))/10 as sum_dt
,sum(if(u.T_flag = 1, pow(o.temp - m.temp,2),null))/100 as sum2_dt
,count(if(u.W_flag = 1, o.wd + m.wd,null)) as N_dw
,sum(if(u.W_flag = 1 and m.ws is not null,o.ws,null)) as sum_ob_ws
,sum(if(u.W_flag = 1 and o.ws is not null,m.ws,null)) as sum_model_ws
,sum(if(u.W_flag = 1, o.ws*sin(o.wd/57.2658) - m.ws*sin(m.wd/57.2658),null)) as sum_du
,sum(if(u.W_flag = 1, o.ws*cos(o.wd/57.2658) - m.ws*cos(m.wd/57.2658),null)) as sum_dv
,sum(if(u.W_flag = 1, pow(o.ws,2)+pow(m.ws,2)-  2*o.ws*m.ws*cos((o.wd-m.wd)/57.2958),null)) as sum2_dw
,count(if(u.Td_flag = 1, o.dp - m.dp,null)) as N_dtd
,sum(if(u.Td_flag = 1 and m.dp is not null,o.dp,null))/10 as sum_ob_dp
,sum(if(u.Td_flag = 1, o.dp - m.dp,null))/10 as sum_dtd
,sum(if(u.Td_flag = 1, pow(o.dp - m.dp,2),null))/100 as sum2_dtd
,count(if(u.Td_flag = 1, o.rh - m.rh,null)) as N_drh
,sum(if(u.Td_flag = 1 and m.rh is not null,o.rh,null))/10 as sum_ob_rh
,sum(if(u.Td_flag = 1, o.rh - m.rh,null))/10 as sum_drh
,sum(if(u.Td_flag = 1, pow(o.rh - m.rh,2),null))/100 as sum2_drh
EOI
    if($has_mae) {
	$query .=<<"EOI"
,sum(if(u.T_flag = 1, abs(o.temp - m.temp),null))/10 as sum_adt
,sum(if(u.Td_flag = 1, abs(o.dp - m.dp),null))/10 as sum_adtd
EOI
}
$query .=<<"EOI"
from $db_name.hr_obs_$valid_time as o
STRAIGHT_JOIN $db_name.${model}qp as m #ignore index (time_id)
STRAIGHT_JOIN $db_name.metars as s
STRAIGHT_JOIN $db_name.$USELIST_TABLE as u
where 1=1
and find_in_set("$region",reg) > 0
and o.sta_id = m.sta_id
and o.sta_id = s.madis_id
and o.sta_id = u.sta_id
and m.fcst_len = $fcst_len
and o.time = m.time
$bad_id_string
and o.time >= $valid_time - 1800
and o.time < $valid_time + 1800
#group by valid_day,hour,fcst_len
EOI
    ;
if($DEBUG) {
    #print "$query";
 }
my $rows = $dbh->do($query);
print "..$rows rows affected\n";
my $warnings = $dbh->selectall_arrayref('SHOW WARNINGS');
for my $row (@$warnings) {
    print "\t@$row\n";
}
my $n_bad = @bad_ids;
if($n_bad > 0) {
    print "\t(left out $n_bad bad stations in table madis3.bad_obs_for_summaries)\n";
}
}
  1;  
