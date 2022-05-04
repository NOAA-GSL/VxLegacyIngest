#!/usr/bin/perl
use strict;
use Time::Local;
my $DEBUG=1;

my $model = $ARGV[0] ||
    die "usage: prepare_new_model.pl <model name>\n";

use DBI;
#set database connection parameters
$ENV{DBI_DSN} = "DBI:mysql:ruc_ua_pb_sums2:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "UA_realtime";
$ENV{DBI_PASS} = "newupper";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $sth;
my $query="";
$dbh->do("use ruc_ua_pb");
$query = qq(select calculator from ruc_ua.dp_to_rh_calculator_per_model where model = "$model");
print "in ruc_ua_pb db: $query\n";
my $rh_calculator = $dbh->selectrow_array($query);
unless($rh_calculator) {
    die "No entery for $model in ruc_ua.dp_to_rh_calculator_per_model. Quitting.\n";
}
my $now = time();
my $t_string = sql_date_hour($now);
#print "calculator: |$rh_calculator| |$t_string| $now\n";
$query = qq|replace into ruc_ua_pb.dp_to_rh_calculator_per_model values("$model","$rh_calculator","added $t_string")|;
print "$query\n";
$dbh->do($query);

$query = qq|select fcst_lens from ruc_ua.fcst_lens_per_model where model = "$model"|;
print "$query\n";
my $model_str = $dbh->selectrow_array($query);
#print "model str: |$model_str|\n";
$query = qq|replace into ruc_ua_pb.fcst_lens_per_model values("$model","$model_str")|;
print "$query\n";
$dbh->do($query);

$query = qq|select reg from ruc_ua.enclosing_region where model = "$model"|;
print "$query\n";
my $reg= $dbh->selectrow_array($query);
$query = qq|replace into ruc_ua_pb.enclosing_region values("$model","$reg")|;
print "$query\n";
$dbh->do($query);

$query = qq|select regions from ruc_ua.regions_per_model where model = "$model"|;
print "$query\n";
my $regions = $dbh->selectrow_array($query);
# remove any regions we no longer have
my $unused_regions = '^1$|^2$|^3$|^4$|^5$|^15$|^16$';
my @regions = split(',',$regions);
print "before; @regions\n";
@regions = grep {!/$unused_regions/} @regions;
print "after: @regions (removed unused regions)\n";
$regions = join(',',@regions);
$query = qq|replace into ruc_ua_pb.regions_per_model values("$model","$regions")|;
print "$query\n";
$dbh->do($query);

sub sql_date_hour {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return (sprintf("%4d-%2.2d-%2.2d %2.2dZ",$year,$mon,$mday,$hour));
}
