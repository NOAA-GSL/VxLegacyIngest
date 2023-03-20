sub update_summaries2 {
    my($model,$valid_time,$fcst_lens_ptr,$regions_ptr,$thresholds_ptr,$DEBUG) = @_;
    my @fcst_lens = @$fcst_lens_ptr;
    if(scalar @fcst_lens == 0) {
	return;
    }
    my $fcst_lens = join(',',@fcst_lens);
    print(" PROCESSED fcst_lens into update_summaries2 for valid time $valid_time: |$fcst_lens|\n");
    my @regions = @$regions_ptr;
    my @thresholds = @$thresholds_ptr;
    use DBI;
    use DBI;
    #connect
    require "./set_connection.pl";
    my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
    my $query = "";
    $query = "use visibility_sums2";
    print("$query\n");
    $dbh->do($query);

foreach my $region (@regions)  {
    my $table = "${model}_$region";
    $query = qq(show tables like "$table");
    my $result = $dbh->selectrow_array($query);
    unless($result) {
       $query = "create table $table like template";
       $dbh->do($query);
    }
    $query = qq[
select 1*3600*floor((o.time+1800)/(1*3600)) as time
,m.fcst_len as fcst_len
 ];
    my $thresh_string="";
foreach my $thresh (@thresholds) { 
    $query .= qq[
,sum(if(    (m.vis100 < $thresh) and     (o.vis100 < $thresh),1,0)) as yy$thresh
,sum(if(    (m.vis100 < $thresh) and NOT (o.vis100 < $thresh),1,0)) as yn$thresh
,sum(if(NOT (m.vis100 < $thresh) and     (o.vis100 < $thresh),1,0)) as ny$thresh
,sum(if(NOT (m.vis100 < $thresh) and NOT (o.vis100 < $thresh),1,0)) as nn$thresh];
}
    $query .= qq[
$thresh_string
from
visibility.$model as m,madis3.metars as loc,visibility.obs as o
where 1 = 1
and m.madis_id = loc.madis_id
and m.madis_id = o.madis_id
and m.fcst_len IN($fcst_lens)
and m.time = o.time];    

    if($region eq "RUC") {
        $query .= qq[  and find_in_set("ALL_RUC",loc.reg) > 0];

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
and find_in_set("AK",loc.reg) > 0];
    } elsif($region eq "HI") {
	$query .= qq[
and find_in_set("HI",loc.reg) > 0];
    } elsif($region eq "ALL_HRRR") {
        $query .= qq[  and find_in_set("ALL_HRRR",loc.reg) > 0];
    } elsif($region eq "ALL_HRRR_coastal") {
        $query .= qq[  and find_in_set("ALL_HRRR",loc.reg) > 0
                       and  loc.coastal=1 ];
    } elsif($region eq "RR_coastal") {
        $query .= qq[  and find_in_set("ALL_RR1",loc.reg) > 0
                       and  loc.coastal=1 ];
    } elsif($region eq "RR") {
        $query .= qq[  and find_in_set("ALL_RR1",loc.reg) > 0
                        ];
    } elsif($region eq "E_HRRR") {
        $query .= qq[  and find_in_set("E_HRRR",loc.reg) > 0];
    } elsif($region eq "W_HRRR") {
        $query .= qq[ and find_in_set("W_HRRR",loc.reg) > 0];
    } else {
	# compare everything -- no where clause
    }

    $query .= qq[
and o.time  >= $valid_time - 1800
and o.time < $valid_time + 1800
# shouldn't need the two lines below, but they speed up the query
# by a factor of > 10! (not obvious from the 'explain' output)
and m.time  >= $valid_time - 1800
and m.time < $valid_time + 1800		 
group by time,fcst_len
having yy$thresholds[0]+yn$thresholds[0]+ny$thresholds[0]+nn$thresholds[0]> 0
order by time];
    
    #print "$query;\n";
    my $sth_thresh = $dbh->prepare($query);
    $sth_thresh->execute();
    my $r;
    my $tmp_file_name = "tmp/$$.sum_data.tmp";
    open(FH, '>', $tmp_file_name) or die $!;
    while($r = $sth_thresh->fetchrow_hashref()) {
	foreach my $thresh (@thresholds) {
	    print FH qq|$$r{time},$$r{fcst_len},$thresh,$$r{"yy$thresh"},$$r{"yn$thresh"},$$r{"ny$thresh"},$$r{"nn$thresh"}\n|;
	}
    }
    close(FH);
    $query=<<"EOI";
load data concurrent local infile '$tmp_file_name'
replace into table $table columns terminated by ','
(time,fcst_len,trsh,yy,yn,ny,nn)
EOI

    #print("$query");
    my $n_rows = $dbh->do($query);
    print("$n_rows row(s) into $table for time $valid_time and threshs @thresholds\n");
    unlink($tmp_file_name);
 }   # end loop over regions

$dbh->disconnect();
}
1;
