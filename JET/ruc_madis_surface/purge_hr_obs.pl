#!/usr/bin/perl
use strict;
use DBI;
use Time::Local;

# connect to the database
$ENV{DBI_DSN} = "DBI:mysql:madis3:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "sfc_driver5";
$ENV{DBI_PASS} = "driver5";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $sth;
my $query;

my $days_ago = defined $ARGV[0] ? $ARGV[0] : 1;
my $purge_secs = time() - $days_ago*24*3600;
my $purge_str = gmtime($purge_secs);
print "time to purge is $purge_str\n";

$dbh->do("use madis3");
$query=<<"EOI"
show tables like "hr_obs%"
EOI
    ;
$sth = $dbh->prepare($query);
$sth->execute();
my($table,$valid_secs);
$sth->bind_columns(\$table);
while($sth->fetch()) {
    $table =~ /hr_obs_(\d+)/;
    $valid_secs = $1;
    my $valid_str = gmtime($valid_secs);
    if($valid_secs < $purge_secs) {
	$query = "drop table $table";
	print "$query (valid $valid_str)\n";
	$dbh->do($query);
    }
}

