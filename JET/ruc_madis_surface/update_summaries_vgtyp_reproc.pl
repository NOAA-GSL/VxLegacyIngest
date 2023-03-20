sub update_summaries_vgtyp {
    my($model,$valid_time,$fcst_len,$dbh,$db_name,$DEBUG) = @_;
    use Time::Local;
    use DBI;
    my $vt_str = gmtime($valid_time);
    my $query = "";
    my $sth;
    my $table = "madis3.${model}qp";
    $query = "describe $table";
    $sth = $dbh->prepare($query);
    $sth->execute();
    my $has_vgtyp=0;
    while(my $ref = $sth->fetchrow_hashref()) {
	if($ref->{Field} eq "vgtyp") {
	    $has_vgtyp=1;
	    last;
	}
    }
    unless($has_vgtyp) {
	if($DEBUG) {
	    print "no vgtyp for $model\n";
	}
	return;
    }
    # the table in madis3 has vgtyp--we can generate vgtyp sums
    $table = "surface_sums.${model}_vgtyp";
    my $field_list = "valid_day,hour,fcst_len,vgtyp,N_dt,sum_ob_t,sum_dt,sum2_dt,".
	"N_dw,sum_ob_ws,sum_model_ws,sum_du,sum_dv,sum2_dw,".
	"N_dtd,sum_ob_td,sum_dtd,sum2_dtd";
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

    if($fcst_len == 1) {
	# get rid of non-METAR reports from previous (buggy) vgtyp updates.
	my $valid_hour = ($valid_time % (24*3600))/3600;
	my $valid_day = $valid_time - 3600*$valid_hour;
	$query = qq{delete from $table where fcst_len = 1 and valid_day = $valid_day and hour = $valid_hour};
	print "$query;\n";
	my $rows = $dbh->do($query);
	print "$rows rows affected\n";
   }
    print "updating $fcst_len h fcst summaries in $table for $vt_str\n";
    $query =<<"EOI";
replace into $table
($field_list)
select floor((m.time+1800)/(24*3600))*(24*3600) as valid_day
,floor(((m.time+1800)%(24*3600))/3600) as hour
,m.fcst_len
,m.vgtyp
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
EOI
    if($has_mae) {
	$query .=<<"EOI"
,sum(abs(o.temp - m.temp))/10 as sum_adt
,sum(abs(o.dp - m.dp))/10 as sum_adtd
EOI
}
$query .=<<"EOI"
from $db_name.obs as o
STRAIGHT_JOIN $db_name.${model}qp as m #ignore index (time_id)
STRAIGHT_JOIN $db_name.metars as s
where 1=1
and o.sta_id = m.sta_id
and o.sta_id = s.madis_id
and m.fcst_len = $fcst_len
and o.time = m.time
and o.time >= $valid_time - 1800
and o.time < $valid_time + 1800
group by valid_day,hour,fcst_len,vgtyp
EOI
    ; #
if($DEBUG) {
    #print "$query";
}
my $rows = $dbh->do($query);
	 #print "$rows row replaced/added to $table for fcst_len $fcst_len\n";
}
  1;  
