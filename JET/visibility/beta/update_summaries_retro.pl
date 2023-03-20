sub update_summaries {
    my($model,$valid_time,$fcst_len,$DEBUG) = @_;
    use DBI;
    use DBI;
    #connect
    require "./set_connection.pl";
    # re-set the db to visibility_sums2
    $ENV{DBI_DSN} = "DBI:mysql:visibility_sums2:wolphin.fsl.noaa.gov";
    my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
    my $query = "";

    print "FILLING SUMMARY TABLES FOR $model for $fcst_len fcst valid at $valid_string\n\n";

    my $retro_temp = "";
    if ($model =~ /AK/) {
       $retro_temp = "AK_retro";
    } elsif ($model =~ /HRRR/) {
       $retro_temp = "HRRR_retro";
    } else {
       $retro_temp = "RAP_retro";
    }

    # find out necessary regions
    $query =<<"EOI"
select regions_name from visibility.regions_per_model where 1=1
and model = "$retro_temp"
EOI
;
    my @result = $dbh->selectrow_array($query);
    my @regions = split(/,/,$result[0]);
    print "regions are @regions\n";
    # find out necessary thresholds
    $query =<<"EOI"
select thresholds from visibility.thresholds_per_model where 1=1
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
    unless($result) {
       $query = "create table $table like template";
       $dbh->do($query);
    }
    $query = qq[
replace into $table  (time,fcst_len,trsh,yy,yn,ny,nn)
select 1*3600*floor((o.time+1800)/(1*3600)) as time,
 m.fcst_len as fcst_len,
 $thresh as trsh,
 sum(if(    (m.vis100 < $thresh) and     (o.vis100 < $thresh),1,0)) as yy,
 sum(if(    (m.vis100 < $thresh) and NOT (o.vis100 < $thresh),1,0)) as yn,
 sum(if(NOT (m.vis100 < $thresh) and     (o.vis100 < $thresh),1,0)) as ny,
 sum(if(NOT (m.vis100 < $thresh) and NOT (o.vis100 < $thresh),1,0)) as nn
from
visibility.$model as m,madis3.metars,visibility.obs as o
where 1 = 1
and m.madis_id = metars.madis_id
and m.madis_id = o.madis_id
and m.fcst_len = $fcst_len
and m.time = o.time
and m.fcst_len = $fcst_len];    

    if($region eq "RUC") {
        $query .= qq[  and find_in_set("ALL_RUC",reg) > 0];

    }elsif($region eq "GtLk") {
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
    } elsif($region eq "ALL_HRRR") {
        $query .= qq[  and find_in_set("ALL_HRRR",reg) > 0];
    } elsif($region eq "ALL_HRRR_coastal") {
        $query .= qq[  and find_in_set("ALL_HRRR",reg) > 0
                       and  metars.coastal=1 ];
    } elsif($region eq "RR_coastal") {
        $query .= qq[  and find_in_set("ALL_RR1",reg) > 0
                       and  metars.coastal=1 ];
    } elsif($region eq "RR") {
        $query .= qq[  and find_in_set("ALL_RR1",reg) > 0
                        ];
    } elsif($region eq "E_HRRR") {
        $query .= qq[  and find_in_set("E_HRRR",reg) > 0];
    } elsif($region eq "W_HRRR") {
        $query .= qq[ and find_in_set("W_HRRR",reg) > 0];
    } else {
	# compare everything -- no where clause
    }
#}

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
    
	print "$query;\n";
    if($DEBUG) {
#	print "$query;\n";
    }
    my $n_rows = $dbh->do($query);
    if($DEBUG) {
	my $time_str = gmtime($valid_time);
	print "$n_rows row(s) updated in $table for $time_str\n"
	}
}}

$dbh->disconnect();
}
1;
