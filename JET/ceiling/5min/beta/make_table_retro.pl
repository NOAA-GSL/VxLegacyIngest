#!/usr/bin/perl

use POSIX qw(strftime);
use Time::Local;
use DBI;
#connect
require "./set_connection.pl";
# re-set the db to ceiling_sums
$ENV{DBI_DSN} = "DBI:mysql:ceiling_sums2:wolphin";
my $dbh = DBI->connect(undef,undef,undef);

my $data_source = $ARGV[0];

my $query = qq[create table ceiling2.$data_source like ceiling2.template];
print "$query\n";
$dbh->do($query);

my $retro_temp = "";
if ($data_source =~ /HRRR/) {
  $retro_temp = "HRRR_retro";
} elsif ($data_source =~ /AK/) {
  $retro_temp = "AK_retro";
} elsif ($data_source =~ /HI/) {
  $retro_temp = "HI_retro";
} else {
  $retro_temp = "RAP_retro";
}

$query =<<"EOI"
select regions_name from ceiling2.regions_per_model where 1=1
and model = "$retro_temp"
EOI
;
my @result = $dbh->selectrow_array($query);
my @regions = split(/,/,$result[0]);
print "regions are @regions\n";

foreach my $region (@regions)  {
    my $template = "template";
    my $table = "${data_source}_$region";

    my $query = qq(show tables like "$table");
    my $result = $dbh->selectrow_array($query);

    print "query is: $query\n";
    print "result is $result\n";
    unless ($result) {

      $query = qq[create table $table like $template];

      print "$query\n";
      $dbh->do($query);
    } 
}

$dbh->disconnect();

1;
