sub update_summaries {
    my($model,$valid_time,$fcst_len,$fcst_min,$DEBUG) = @_;
    use Time::Local;
    use DBI;
    #connect
    $ENV{DBI_USER} = "wcron0_user";
    $ENV{DBI_PASS} = "cohen_lee";
    $ENV{DBI_DSN} = "DBI:mysql:vis_1min_sums:wolphin";
    my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
    my $valid_string = gmtime($valid_time);
    print "FILLING SUMMARY TABLES FOR $model for $fcst_len hr $fcst_min min fcst valid at $valid_string\n\n";

    my $VIS_STD_LIMIT = 240;  # approx mean + 3 std for vis_std, for those obs with some limited vis in the 10 min window

    # find out necessary regions
    $query =<<"EOI"
select regions from vis_1min.model_metadata where 1=1
and model = "$model"
EOI
;
    my @result = $dbh->selectrow_array($query);
    my @regions = split(/,/,$result[0]);
    print "regions are @regions\n";
    # find out necessary thresholds
    $query =<<"EOI"
select thresholds from vis_1min.model_metadata where 1=1
and model = "$model"
EOI
;
    my @result = $dbh->selectrow_array($query);
    my @thresholds = split(/,/,$result[0]);
    print "thresholds are @thresholds\n";


foreach my $thresh (@thresholds) {
foreach my $region (@regions)  {
foreach my $truth qw(qc min avg closest) {
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
	$query = qq[
replace into $table (time,fcst_len,fcst_min,trsh,truth,yy,yn,ny,nn)
select o.valid_time as time,
 m.fcst_len as fcst_len,
 m.fcst_min as fcst_min,
 $thresh as trsh,
'$truth' as truth,];
    if($truth ne "qc") {
	$query .= qq[
 sum(if(    (m.vis100 < $thresh) and     (o.vis_$truth < $thresh),1,0)) as yy,
 sum(if(    (m.vis100 < $thresh) and NOT (o.vis_$truth < $thresh),1,0)) as yn,
 sum(if(NOT (m.vis100 < $thresh) and     (o.vis_$truth < $thresh),1,0)) as ny,
 sum(if(NOT (m.vis100 < $thresh) and NOT (o.vis_$truth < $thresh),1,0)) as nn];
    } else {
	$query .= qq[
 sum(if(    (m.vis100 < $thresh) and     (o.vis_closest < $thresh),1,0)) as yy,
 sum(if(    (m.vis100 < $thresh) and NOT (o.vis_closest < $thresh),1,0)) as yn,
 sum(if(NOT (m.vis100 < $thresh) and     (o.vis_closest < $thresh),1,0)) as ny,
 sum(if(NOT (m.vis100 < $thresh) and NOT (o.vis_closest < $thresh),1,0)) as nn];
    }
    $query .= qq[
from
vis_1min.$model as m,1min_asos.metars,vis_1min.obs as o
where 1 = 1
and m.madis_id = metars.madis_id
and m.madis_id = o.madis_id
and m.fcst_len = $fcst_len
and m.fcst_min = $fcst_min
and m.time = o.valid_time
and o.valid_time  = $valid_time
# shouldn't need the line below, but they speed up the query
# by a factor of > 10! (not obvious from the 'explain' output)
and m.time  = $valid_time];  #. (emacs coloration)
if($truth eq "qc") {
    $query .= qq[
and o.vis_std < $VIS_STD_LIMIT];
}
    if($region eq "E_US") {
	$query .= qq[
# larger region for Chautauqua
and lat > 2800 and lat < 4900
and lon > -10200 and lon < -7000];
    } else {
	$query .= qq[
and find_in_set('$region',metars.reg)];
    }
   $query .= qq[
group by o.valid_time
having yy+yn+ny+nn > 0
order by o.valid_time];
    print "query is $query\n";
    my $rows = $dbh->do($query);
    my $str = gmtime($valid_time);
    print "updating table $table (thresh: $thresh) forecast $fcst_len/$fcst_min, valid $str, truth $truth.  $rows rows affected\n";

}}}

$dbh->disconnect();
}
1;
