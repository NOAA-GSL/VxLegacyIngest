sub update_summaries3 {
    my($model,$valid_time,$fcst_len,$DEBUG) = @_;
    use Time::Local;
    use DBI;
    #connect
    require "./set_connection.pl";
    # re-set the db to ceiling_sums
    $ENV{DBI_DSN} = "DBI:mysql:ceiling_sums:wolphin";
    my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
    my $valid_string = gmtime($valid_time);
    print "FILLING SUMMARY TABLES FOR $model for $fcst_len fcst valid at $valid_string\n\n";

foreach my $thresh qw(50 100 300) {
    my @regions = qw(RUC GtLk E_US);
    if($model =~ /^RR/) {
	@regions = qw(RUC GtLk E_US RR AK);
    }
foreach my $region (@regions)  {
    my $table = "${model}_${thresh}_${fcst_len}_$region";
    

    # ORDER IS FORECAST, OBSERVATION!!
    # for the RR model in the RUC region, we need to be special
    if($region eq "RUC" &&
       $model =~ /RR/ ||
       $model eq "NAM") {
	$query = qq[
replace into $table (time,yy,yn,ny,nn)
select 1*3600*floor((o.time+1800)/(1*3600)) as time,
 sum(if(    (m.c$fcst_len < $thresh) and     (o.ceil < $thresh),1,0)) as yy,
 sum(if(    (m.c$fcst_len < $thresh) and NOT (o.ceil < $thresh),1,0)) as yn,
 sum(if(NOT (m.c$fcst_len < $thresh) and     (o.ceil < $thresh),1,0)) as ny,
 sum(if(NOT (m.c$fcst_len < $thresh) and NOT (o.ceil < $thresh),1,0)) as nn
from
ceiling.$model as m,ceiling.metars,ceiling.obs as o,ceiling.ruc_metars as rm
where 1 = 1
and m.madis_id = metars.madis_id
and m.madis_id = o.madis_id
and m.time = o.time
and m.madis_id = rm.madis_id];  #this ensures that this id is in the RUC domain

    } else {
	# things are simpler for other models
    $query = qq[
replace into $table  (time,yy,yn,ny,nn)
select 1*3600*floor((o.time+1800)/(1*3600)) as time,
 sum(if(    (m.c$fcst_len < $thresh) and     (o.ceil < $thresh),1,0)) as yy,
 sum(if(    (m.c$fcst_len < $thresh) and NOT (o.ceil < $thresh),1,0)) as yn,
 sum(if(NOT (m.c$fcst_len < $thresh) and     (o.ceil < $thresh),1,0)) as ny,
 sum(if(NOT (m.c$fcst_len < $thresh) and NOT (o.ceil < $thresh),1,0)) as nn
from
ceiling.$model as m,ceiling.metars,ceiling.obs as o
where 1 = 1
and m.madis_id = metars.madis_id
and m.madis_id = o.madis_id
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
# Alaska region (with some of Canada)
and lat > 5300 and lat < 7200
and lon > -17000 and lon < -12900];
    } else {
	# compare everything -- no where clause
    }
}
    $query .= qq[
and o.time  >= $valid_time - 1800
and o.time < $valid_time + 1800
# shouldn't need the two lines below, but they speed up the query
# by a factor of > 10! (not obvious from the 'explain' output)
and m.time  >= $valid_time - 1800
and m.time < $valid_time + 1800		 
group by time
having yy+yn+ny+nn > 0
order by time];

    $dbh->do($query);

}}

$dbh->disconnect();
}
1;
