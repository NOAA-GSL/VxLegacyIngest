sub update_summaries_retro {
    my($model,$valid_time,$fcst_len,$DEBUG) = @_;
    use Time::Local;
    use DBI;
    #connect
    require "./set_connection.pl";
    # re-set the db to ceiling_sums
    $ENV{DBI_DSN} = "DBI:mysql:ceiling_sums2:wolphin.fsl.noaa.gov";
    my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
    my $valid_string = gmtime($valid_time);
    print "FILLING SUMMARY TABLES FOR $model for $fcst_len fcst valid at $valid_string\n\n";

    my $retro_temp = "";
    if ($data_source =~ /AK/) {
       $retro_temp = "AK_retro";
    } elsif ($data_source =~ /^HRRR/) {
       $retro_temp = "HRRR_retro";
    } elsif ($data_source =~ /^RRFS_NA_13km/) {
       $retro_temp = "RRFS_NA_13km_retro";
    } elsif ($data_source =~ /^RRFS/) {
       $retro_temp = "RRFS_retro";
    } elsif ($data_source =~ /^RTMA/) {
       $retro_temp = "RTMA_retro";
    } else {
       $retro_temp = "RAP_retro";
    }

    # find out necessary regions
    $query =<<"EOI"
select regions_name from ceiling2.regions_per_model where 1=1
and model = "$retro_temp"
EOI
;
    my @result = $dbh->selectrow_array($query);
    my @regions = split(/,/,$result[0]);
    print "regions are @regions\n";
    # find out necessary thresholds
    $query =<<"EOI"
select thresholds from ceiling2.thresholds_per_model where 1=1
and model = "$retro_temp"
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
    print "result is $result\n";
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
	$model eq "NAM" || $model =~ /^RAP/)) {
	$query = qq[
replace into $table (time,fcst_len,trsh,yy,yn,ny,nn)
select 1*3600*floor((o.time+1800)/(1*3600)) as time,
 m.fcst_len as fcst_len,
 $thresh as trsh,
 sum(if(    (m.ceil < $thresh) and     (o.ceil < $thresh),1,0)) as yy,
 sum(if(    (m.ceil < $thresh) and NOT (o.ceil < $thresh),1,0)) as yn,
 sum(if(NOT (m.ceil < $thresh) and     (o.ceil < $thresh),1,0)) as ny,
 sum(if(NOT (m.ceil < $thresh) and NOT (o.ceil < $thresh),1,0)) as nn
from
ceiling2.$model as m,madis3.metars,ceiling2.obs_retro as o,ceiling2.ruc_metars as rm
where 1 = 1
and m.madis_id = metars.madis_id
and m.madis_id = o.madis_id
and m.fcst_len = $fcst_len
and m.time = o.time
and m.madis_id = rm.madis_id];  #this ensures that this id is in the RUC domain

    } else {
	# things are simpler for other models
    $query = qq[
replace into $table  (time,fcst_len,trsh,yy,yn,ny,nn)
select 1*3600*floor((o.time+1800)/(1*3600)) as time,
 m.fcst_len as fcst_len,
 $thresh as trsh,
 sum(if(    (m.ceil < $thresh) and     (o.ceil < $thresh),1,0)) as yy,
 sum(if(    (m.ceil < $thresh) and NOT (o.ceil < $thresh),1,0)) as yn,
 sum(if(NOT (m.ceil < $thresh) and     (o.ceil < $thresh),1,0)) as ny,
 sum(if(NOT (m.ceil < $thresh) and NOT (o.ceil < $thresh),1,0)) as nn
from
ceiling2.$model as m,madis3.metars,ceiling2.obs_retro as o
where 1 = 1
and m.madis_id = metars.madis_id
and m.madis_id = o.madis_id
and m.fcst_len = $fcst_len
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
    } elsif($region eq "RR") {
     $query .= qq[                                                                                                                       
        and find_in_set("ALL_RR1",reg) > 0];
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
    print "query is $query\n";
    $dbh->do($query);

}}

$dbh->disconnect();
}
1;
