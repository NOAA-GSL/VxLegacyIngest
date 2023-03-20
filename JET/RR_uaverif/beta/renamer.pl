#!/usr/bin/perl

use strict;
use DBI;
$ENV{DBI_DSN} = "DBI:mysql:soundings:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "UA_realtime";
$ENV{DBI_PASS} = "newupper";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {PrintError => 1});
my $sth;
my $query="";

my $old_name = $ARGV[0];
my $new_name = $ARGV[1];

if(!defined $old_name) {
    print "usage: renamer.pl <old_name> <new_name>\n";
    exit(1);
}

my $already_there=0;
my $new_soundings_table = "${new_name}_raob_soundings";
$query = qq(show tables like "$new_soundings_table");
$dbh->do("use soundings");
#print "$query\n";
$already_there = $dbh->selectrow_array($query);
if($already_there) {print "soundings db: already_there is $already_there\n";}
unless($already_there) {
    # no table in soundings; checu ruc_ua
    $dbh->do("use ruc_ua");
    $query = qq(show tables like "$new_name");
    #print "$query\n";
    $already_there = $dbh->selectrow_array($query);
    if($already_there) {print "ruc_ua db: already_there is $already_there\n";}
    unless($already_there) {
	# check at least one of the 'per_model' tables
	$query = qq{select * from enclosing_region where model = "$new_name"};
	#print "$query\n";
	$already_there = $dbh->selectrow_array($query);
	if($already_there) {print "ruc_ua.enclosing_region: already_there is $already_there\n";}
    }
}
if($already_there) {
    print "$new_name is already in the database! Exiting.\n";
    exit(1);
}
# now we can rename the tables
$dbh->do("use soundings");
# see if this table is partitioned
my $sounding_table_partitioned=0;
$query = qq(show create table ${old_name}_raob_soundings);
#print "$query\n";
my @result = $dbh->selectrow_array($query);
if($result[1] =~/PARTITION/) {
    #print "a partitioned table!\n";
    $sounding_table_partitioned=1;
}
$query = qq(rename table ${old_name}_raob_soundings to ${new_name}_raob_soundings);
print "$query\n";
$dbh->do($query);
$dbh->do("use ruc_ua");
# see if this table is partitioned
my $ruc_ua_table_partitioned=0;
$query = qq(show create table ${old_name});
print "$query\n";
my @result = $dbh->selectrow_array($query);
if($result[1] =~/PARTITION/) {
    #print "a partitioned table!\n";
    $ruc_ua_table_partitioned=1;
}
$query = qq(rename table ${old_name} to ${new_name});
print "$query\n";
$dbh->do($query);
$query = qq(update dp_to_rh_calculator_per_model set model="$new_name" where model="$old_name");
print "$query\n";
$dbh->do($query);
$query = qq(update fcst_lens_per_model set model="$new_name" where model="$old_name");
print "$query\n";
$dbh->do($query);
$query = qq(update regions_per_model set model="$new_name" where model="$old_name");
print "$query\n";
$dbh->do($query);
$query = qq(update enclosing_region set model="$new_name" where model="$old_name");
print "$query\n";
$dbh->do($query);
$query = qq(select regions from regions_per_model where model = "$new_name");
print "$query\n";
@result = $dbh->selectrow_array($query);
my @regions = split(/,/,$result[0]);
print "regions are @regions\n";
$dbh->do("use ruc_ua_sums2");
foreach my $region (@regions) {
    $query = "rename table ${old_name}_Areg$region to ${new_name}_Areg$region";
    print "$query;\n";
    $dbh->do($query);
}
# look for some special tables
$query = qq(show tables like "${old_name}_cloudy");
my $cloud_tables_there = $dbh->selectrow_array($query);
if($cloud_tables_there) {
    $query = qq(rename table ${old_name}_cloudy to ${new_name}_cloudy);
    $dbh->do($query);
     $query = qq(rename table ${old_name}_clear to ${new_name}_clear);
    $dbh->do($query);
}
$query = qq(show tables like "${old_name}_resids");
my $resids_there =  $dbh->selectrow_array($query);
if($resids_there) {
     $query = qq(rename table ${old_name}_resids to ${new_name}_resids);
    $dbh->do($query);
}

if($sounding_table_partitioned) {
    print "\nWARNING: soundings.${new_name}_raob_soundings is partitioned!\n";
    print qq(be sure to update ratchet's cron entry "update_monthly_partitions.pl soundings.${old_name}_raob_soundings"\n);
    print qq(to "update_monthly_partitions.pl soundings.${new_name}_raob_soundings"\n);
}
if($ruc_ua_table_partitioned) {
    print "\nWARNING: ruc_ua.${new_name} is partitioned!\n";
    print qq(be sure to update ratchet's cron entry "update_monthly_partitions.pl ruc_ua.${old_name}"\n);
    print qq(to "update_monthly_partitions.pl ruc_ua.${new_name}"\n);
}

print "\nthere's much more to do. See https://docs.google.com/a/noaa.gov/document/d/1g4RH2RkFmqF7Hn0dOHBN0vDMexBYAi79LskkVFQmCBg/edit?usp=sharing\n";




	
 
