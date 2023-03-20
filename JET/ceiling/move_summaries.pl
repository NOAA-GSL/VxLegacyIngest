sub move_summaries {
    my($model,$valid_time) = @_;
    use Time::Local;
    use DBI;
    #connect
    require "./set_connection.pl";
    # re-set the db to ceiling_sums
    $ENV{DBI_DSN} = "DBI:mysql:ceiling_sums2:wolphin";
    my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
    my $valid_string = gmtime($valid_time);
    print "FILLING SUMMARY TABLES FOR $model for $fcst_len fcst valid at $valid_string\n\n";

$dbh->do("use ceiling2");
# find our necessary regions
$query =<<"EOI"
select regions_name from ceiling2.regions_per_model where 1=1
and model = "$model"
EOI
;
my @result = $dbh->selectrow_array($query);
my @regions = split(/,/,$result[0]);
# find out necessary thresholds
$query =<<"EOI"
select thresholds from ceiling2.thresholds_per_model where 1=1
and model = "$model"
EOI
;
my @result = $dbh->selectrow_array($query);
my @thresholds = split(/,/,$result[0]);
# find our necessary fcst lengths
$query =<<"EOI"
select fcst_lens from ceiling2.fcst_lens_per_model where 1=1
and model = "$model"
EOI
;
my @result = $dbh->selectrow_array($query);
my @fcst_lens = split(/,/,$result[0]);
$dbh->do("use ceiling_sums2");

print "regions: @regions\n";
print "thresholds: @thresholds\n";
print "fcst_lens: @fcst_lens\n";

foreach my $region (@regions)  {
    my $table = "${model}_$region";
    
    print "table=$table \n";

    $query = qq(show tables like "$table");
    my $result = $dbh->selectrow_array($query);
    unless($result) {
       $query = "create table $table like template";
       $dbh->do($query);
    }
    foreach my $thresh (@thresholds) {
    print "$model\n";
    print "$thresh\n";
    if ($model eq "persis" && $thresh eq "6000") {
       next;
    } 
    foreach my $fcst_len (@fcst_lens) {
    my $old_table = "${model}_${thresh}_${fcst_len}_$region";
    $query = qq[
replace into $table (time,fcst_len,trsh,yy,yn,ny,nn)
select ot.time as time,
 $fcst_len as fcst_len,
 $thresh as trsh,
 ot.yy as yy,
 ot.yn as yn,
 ot.ny as ny,
 ot.nn as nn
from
ceiling_sums.$old_table as ot
where 1 = 1
and ot.time = $valid_time
]; 
    print "query=$query\n";
    $dbh->do($query);

}}}

$dbh->disconnect();
}
1;
