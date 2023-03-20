#!/usr/bin/perl

use POSIX qw(strftime);
use Time::Local;
use DBI;
#connect
require "./set_connection.pl";
# re-set the db to ceiling_sums
$ENV{DBI_DSN} = "DBI:mysql:visibility_sums:wolphin";
my $dbh = DBI->connect(undef,undef,undef);

#my @regions = qw(RUC GtLk E_US AK);
my @regions = qw(AK ALL_HRRR ALL_HRRR_coastal E_HRRR E_US GtLk RR RR_coastal RUC W_HRRR);

my $data_source = "RAP_NCEP";
my $new_data_source = "RAP_OPS_130";

foreach my $thresh qw(50 100 300 500 1000) {
foreach my $region (@regions)  {
foreach my $fcst_len qw(0 1 3 6 9 12 15 18) {
    my $old_table = "${data_source}_${thresh}_${fcst_len}_$region";
    my $new_table = "${new_data_source}_${thresh}_${fcst_len}_$region";

    my $query = qq(show tables like "$old_table");
    my $result = $dbh->selectrow_array($query);

    print "query is: $query\n";
    print "result is $result\n";
    if ($result) {

      $query = qq[rename table $old_table to $new_table];

      print "$query\n";
      $dbh->do($query);
    } else {
      print "$old_table doesn't exist\n";
    }
}}}

$dbh->disconnect();

1;
