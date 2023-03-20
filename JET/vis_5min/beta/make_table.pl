#!/usr/bin/perl

use POSIX qw(strftime);
use Time::Local;
use DBI;
#connect
require "./set_connection.pl";
# re-set the db to ceiling_sums
$ENV{DBI_DSN} = "DBI:mysql:visibility_sums:wolphin";
my $dbh = DBI->connect(undef,undef,undef);

my $data_source = $ARGV[0];

$query =<<"EOI"
select regions_name from visibility.regions_per_model where 1=1
and model = "$data_source"
EOI
;
my @result = $dbh->selectrow_array($query);
my @regions = split(/,/,$result[0]);
print "regions are @regions\n";

$query =<<"EOI"
select fcst_lens from visibility.fcst_lens_per_model where 1=1
and model = "$data_source"
EOI
;
my @result = $dbh->selectrow_array($query);
my @fcst_lens = split(/,/,$result[0]);
print "fcst_lens are @fcst_lens\n";

$query =<<"EOI"
select thresholds from visibility.thresholds_per_model where 1=1
and model = "$data_source"
EOI
;
my @result = $dbh->selectrow_array($query);
my @thresholds = split(/,/,$result[0]);
print "thresholds are @thresholds\n";


foreach my $thresh (@thresholds) {
foreach my $region (@regions)  {
foreach my $fcst_len (@fcst_lens) {
    my $template = "HRRR_50_0_ALL_HRRR";
    my $table = "${data_source}_${thresh}_${fcst_len}_$region";

    my $query = qq(show tables like "$table");
    my $result = $dbh->selectrow_array($query);

    print "query is: $query\n";
    print "result is $result\n";
    unless ($result) {

      $query = qq[create table $table like $template];

      print "$query\n";
      $dbh->do($query);
    } 
}}}

$dbh->disconnect();

1;
