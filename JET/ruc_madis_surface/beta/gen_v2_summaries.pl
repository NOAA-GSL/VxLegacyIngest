#!/usr/bin/perl
#
use strict;
use Time::Local;
use DBI;
require "./set_connection.pl";
$ENV{DBI_DSN} = "DBI:mysql:surface_sums:wolphin.fsl.noaa.gov";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 0, PrintError => 1});
my $sth;
my $query;
$dbh->do("use surface_sums");
foreach my $model (qw( RAP_dev1)) {
    $query=qq[show tables from surface_sums where Tables_in_surface_sums regexp "^$model\_[0-9]{1,2}_metar_q"];
    $sth = $dbh->prepare($query);
    $sth->execute();
    my $table;
    my %fcst_lens;
    my %regions;
   $sth->bind_columns(\$table);
    while($sth->fetch()) {
	$table =~ /${model}_(\d*)_metar_q_(.*)/;
	my $fcst_len = $1;
	$fcst_lens{$fcst_len}++;
	my $region = $2;
	$regions{$region}++;
	print "$fcst_len $region $table\n";
    }
    if(1) {
    foreach my $region (sort keys %regions) {
	my $new_table = "${model}_metar_v2_$region";
	$query = qq[create table if not exists $new_table like ${model}_0_metar_q_$region];
	print "$query\n";
	$dbh->do($query);
	foreach my $fcst_len (sort {$a - $b} keys %fcst_lens) {
	    $query = qq[insert ignore into $new_table select * from ${model}_${fcst_len}_metar_q_$region];
	    print "$query\n";
	    my $n_rows = $dbh->do($query);
	    print "$n_rows rows inserted\n";
	}
    }}
}
 
