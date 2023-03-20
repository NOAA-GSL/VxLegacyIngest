sub update_summaries {
    my($model,$valid_time,$fcst_len,$fcst_min,$DEBUG) = @_;
    use Time::Local;
    use DBI;
    #connect
    $ENV{DBI_USER} = "wcron0_user";
    $ENV{DBI_PASS} = "cohen_lee";
    $ENV{DBI_DSN} = "DBI:mysql:ceiling_5min_sums:wolphin";
    my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
    my $valid_string = gmtime($valid_time);
    print "FILLING SUMMARY TABLES FOR $model for $fcst_len hr $fcst_min min fcst valid at $valid_string\n\n";

    # find out necessary regions
    $query =<<"EOI"
select regions from ceiling_5min.model_metadata where 1=1
and model = "$model"
EOI
;
    my @result = $dbh->selectrow_array($query);
    my @regions = split(/,/,$result[0]);
    print "regions are @regions\n";
    # find out necessary thresholds
    $query =<<"EOI"
select thresholds from ceiling_5min.model_metadata where 1=1
and model = "$model"
EOI
;
    my @result = $dbh->selectrow_array($query);
    my @thresholds = split(/,/,$result[0]);
    print "thresholds are @thresholds\n";


foreach my $thresh (@thresholds) {
foreach my $region (@regions)  {
    my $table = "${model}_$region";
    
    
    $query = qq(show tables like "$table");
    my $result = $dbh->selectrow_array($query);
    #print "result is $result\n";
    unless($result) {
       # need to create the necessary tables
       $query = "create table $table like template";
       print "$query;\n";
       $dbh->do($query);
    }

    # ORDER IS FORECAST, OBSERVATION!!
    # for the RR model in the RUC region, we need to be special
    if($region eq "RUC" &&
       ($model =~ /RR/ ||
	$model eq "NAM")) {
	$query = qq[
replace into $table (time,fcst_len,fcst_min,trsh,yy,yn,ny,nn)
select 1*900*floor((o.time+450)/(1*900)) as time,
 m.fcst_len as fcst_len,
 m.fcst_min as fcst_min,
 $thresh as trsh,
 sum(if(    (m.ceil < $thresh) and     (o.ceil < $thresh),1,0)) as yy,
 sum(if(    (m.ceil < $thresh) and NOT (o.ceil < $thresh),1,0)) as yn,
 sum(if(NOT (m.ceil < $thresh) and     (o.ceil < $thresh),1,0)) as ny,
 sum(if(NOT (m.ceil < $thresh) and NOT (o.ceil < $thresh),1,0)) as nn
from
ceiling_5min.$model as m,metars_5min.metars,ceiling_5min.obs as o,ceiling_5min.ruc_metars as rm
where 1 = 1
and m.madis_id = metars.madis_id
and m.madis_id = o.madis_id
and m.fcst_len = $fcst_len
and m.fcst_min = $fcst_min
and m.time = o.time
and m.madis_id = rm.madis_id];  #this ensures that this id is in the RUC domain

    } else {
	# things are simpler for other models
    $query = qq[
replace into $table  (time,fcst_len,fcst_min,trsh,yy,yn,ny,nn)
select 1*900*floor((o.time+450)/(1*900)) as time,
 m.fcst_len as fcst_len,
 m.fcst_min as fcst_min,
 $thresh as trsh,
 sum(if(    (m.ceil < $thresh) and     (o.ceil < $thresh),1,0)) as yy,
 sum(if(    (m.ceil < $thresh) and NOT (o.ceil < $thresh),1,0)) as yn,
 sum(if(NOT (m.ceil < $thresh) and     (o.ceil < $thresh),1,0)) as ny,
 sum(if(NOT (m.ceil < $thresh) and NOT (o.ceil < $thresh),1,0)) as nn
from
ceiling_5min.$model as m,metars_5min.metars,ceiling_5min.obs as o
where 1 = 1
and m.madis_id = metars.madis_id
and m.madis_id = o.madis_id
and m.fcst_len = $fcst_len
and m.fcst_min = $fcst_min
and m.time = o.time];
    if($region eq "GtLk") {
	$query .= qq[
# Great Lakes region (approx)
and lat >= 3800 and lat <= 4900
and lon >= -9900 and lon <= -7900];
    } elsif($region eq "E_US") {
	$query .= qq[
# larger region for Chautauqua
and lat > 2800 and lat < 4900
and lon > -10200 and lon < -7000];
    } elsif($region eq "AK") {
     $query .= qq[                                                                                                                       
        and find_in_set("AK",reg) > 0];
    } elsif($region eq "HI") {
     $query .= qq[                                                                                                                       
        and find_in_set("HI",reg) > 0];
    } else {
	# compare everything -- no where clause
    }
}
    $query .= qq[
and o.time  >= $valid_time - 450
and o.time < $valid_time + 450
# shouldn't need the two lines below, but they speed up the query
# by a factor of > 10! (not obvious from the 'explain' output)
and m.time  >= $valid_time - 450
and m.time < $valid_time + 450		 
group by time
having yy+yn+ny+nn > 0
order by time];
    #print "query is $query\n";
    my $rows = $dbh->do($query);
    my $str = gmtime($valid_time);
    print "updating table $table (thresh: $thresh) forecast $fcst_len/$fcst_min, valid $str.  $rows rows affected\n";

}}

$dbh->disconnect();
}
1;
