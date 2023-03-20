sub move_summaries {
    my($model,$valid_time) = @_;
    use Time::Local;
    use DBI;
    #connect
    require "./set_connection3.pl";
    # re-set the db to ceiling_sums
    $ENV{DBI_DSN} = "DBI:mysql:surface_sums2:wolphin";
    my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
    my $valid_string = gmtime($valid_time);
    print "FILLING SUMMARY TABLES FOR $model for $fcst_len fcst valid at $valid_string\n\n";
    #print "Valid Time = $valid_time\n";

$dbh->do("use madis3");

my $retro_temp = "";
if ($model =~ /HRRR/) {
  $retro_temp = "HRRR_retro";
} elsif ($model =~ /AK/) {
  $retro_temp = "AK_retro";
} elsif ($model =~ /HI/) {
  $retro_temp = "HI_retro";
} else {
  $retro_temp = "RAP_retro";
}

# find our necessary regions
$query =<<"EOI"
select regions_name from madis3.regions_per_model where 1=1
and model = "$retro_temp"
EOI
;
my @result = $dbh->selectrow_array($query);
my @regions = split(/,/,$result[0]);
# find our necessary fcst lengths
$query =<<"EOI"
select fcst_lens from madis3.fcst_lens_per_model where 1=1
and model = "$retro_temp"
EOI
;
my @result = $dbh->selectrow_array($query);
my @fcst_lens = split(/,/,$result[0]);
$dbh->do("use surface_sums2");


foreach my $region (@regions)  {
    my $table = "${model}_metar_v2_$region";
    
    #print "New table: $table \n";

    $dbh->do("use surface_sums2");
    $query = qq(show tables like "$table");
    my $result = $dbh->selectrow_array($query);
    unless($result) {
       $query = "create table $table like template";
       $dbh->do($query);
    }
    foreach my $fcst_len (@fcst_lens) {
    my $old_table = "${model}_${fcst_len}_metar_$region";
    $dbh->do("use surface_sums");
    $query = qq(show tables like "$old_table");
    my $result = $dbh->selectrow_array($query);
    if(!$result) {
      #print "$old_table does not exist\n";
    } else {
    $dbh->do("use surface_sums2");
    $query = qq[
replace into $table (valid_day,hour,fcst_len,N_dt,sum_ob_t,sum_dt,sum2_dt,
 N_dw,sum_ob_ws,sum_model_ws,sum_du,sum_dv,sum2_dw,
 N_dtd,sum_ob_td,sum_dtd,sum2_dtd)
 select ot.valid_day as valid_day,
 ot.hour as hour,
 ot.fcst_len as fcst_len,
 ot.N_dt as N_dt,
 ot.sum_ob_t as sum_ob_t,
 ot.sum_dt as sum_dt,
 ot.sum2_dt as sum2_dt,
 ot.N_dw as N_dw,
 ot.sum_ob_ws as sum_ob_ws,
 ot.sum_model_ws as sum_model_ws,
 ot.sum_du as sum_du,
 ot.sum_dv as sum_dv,
 ot.sum2_dw as sum2_dw,
 ot.N_dtd as N_dtd,
 ot.sum_ob_td as sum_ob_td,
 ot.sum_dtd as sum_dtd,
 ot.sum2_dtd as sum2_dtd
from
surface_sums.$old_table as ot
where 1 = 1
and ot.valid_day = $valid_time
]; 
    print "query=$query\n";
    $dbh->do($query);
    }
}}

$dbh->disconnect();
}
1;
