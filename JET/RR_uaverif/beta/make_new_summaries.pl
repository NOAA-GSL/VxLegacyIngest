#!/usr/bin/perl
use strict;
use strict;
use Time::Local;
use DBI;
$ENV{DBI_DSN} = "DBI:mysql:ruc_ua_sums2:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 0, PrintError => 1});
my $query;
my $model;
my @regions;
foreach $model (qw(RAP_OPS_130)) {
    $query =<<"EOI"
select regions from ruc_ua.regions_per_model where 1=1
and model = "$model"
EOI
;
    my @result = $dbh->selectrow_array($query);
    @regions = split(/,/,$result[0]);
    print "regions for $model are @regions\n";

#foreach my $reg  (@regions) {
foreach my $reg  (14) {
    my $new_table = "${model}_Areg$reg";
    my $like_table = "GFS_Areg$reg";
    $query = qq{create table $new_table like $like_table};
    print "$query\n";
    $dbh->do($query) or
	die "$dbh->{errstr}";
}
}
