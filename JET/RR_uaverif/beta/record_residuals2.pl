#!/usr/bin/perl

use DBI;
my $dbh = DBI->connect(
    "DBI:mysql:ruc_ua:wolphin.fsl.noaa.gov",
    "UA_realtime","newupper", {RaiseError => 1}
    );
record_raob_resids2($dbh,'RAP20',1370044800,1385856000  ,3);
1;

sub record_raob_resids2 {
    my($dbh,$model,$start_time,$end_time,$fcst_len) = @_;
    my $query;
    my $resids_table = "${model}_resids";
    my $tmp_table = "max_difs";
    my $start_valid_day = sql_date($start_time);
    my $start_valid_hour = ($start_time%(24*3600))/3600;
    my $end_valid_day = sql_date($end_time);
    my $end_valid_hour = ($end_time%(24*3600))/3600;
    $dbh->do("use ruc_ua");
    $query=<<"EOQ"
show tables like "$resids_table"
EOQ
;
    my($found_table) = $dbh->selectrow_array($query);
    if($found_table) {

	$query=<<"EOQ"
create   table $tmp_table
# describe
select unix_timestamp(RAOB.date)+3600*RAOB.hour as valid_secs
,RAOB.date,RAOB.hour
,RAOB.wmoid
,max(abs(RAOB.T - $model.t)/100) as mx_t_dif
,max(abs(RAOB.ws - $model.ws)/100) as mx_ws_dif
from RAOB,$model
where 1=1
and RAOB.wmoid = $model.wmoid
and RAOB.date = $model.date
and RAOB.hour = $model.hour
and RAOB.press = $model.press
and RAOB.date >= '$start_valid_day'
and RAOB.date <= '$end_valid_day'
and $model.fcst_len = $fcst_len
group by valid_secs,RAOB.wmoid
EOQ
;
	print "$query;\n";
	#$dbh->do($query);

	$query=<<"EOQ"
select valid_secs,wmoid,max(mx_t_dif)
from $tmp_table
order by mx_t_dif desc
limit 1
EOQ
;
	print "$query:\n";
	my($t_wmoid,$mx_t_dif) = $dbh->selectrow_array($query);

	$query=<<"EOQ"
select wmoid,mx_ws_dif
from $tmp_table
order by mx_ws_dif desc
limit 1
EOQ
;
	#print "$query:\n";
	my($ws_wmoid,$mx_ws_dif) = $dbh->selectrow_array($query);

	$query=<<"EOQ"
select avg(mx_t_dif) as avg_t_dif, avg(mx_ws_dif) as avg_ws_dif
from $tmp_table
EOQ
;
	#print "$query:\n";
	my($avg_t_dif,$avg_ws_dif) = $dbh->selectrow_array($query);

	if(defined $avg_t_dif && defined $avg_ws_dif && defined $mx_t_dif && defined $t_wmoid && 
	   defined $mx_ws_dif && defined $ws_wmoid) {
	    $query=<<"EOQ"
replace into $resids_table
VALUES($valid_time,$fcst_len,$avg_t_dif,$avg_ws_dif,$mx_t_dif,$t_wmoid,$mx_ws_dif,$ws_wmoid)
EOQ
;
	    print "$query;\n";
	    $dbh->do($query);
	}
	$dbh->do("drop table $tmp_table");
	
    } else {
	print "WARNING: no table $resids_table. Not saving RAOB residuals.\n";
    }
}

sub sql_date {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d",
		   $year,$mon,$mday);
}
