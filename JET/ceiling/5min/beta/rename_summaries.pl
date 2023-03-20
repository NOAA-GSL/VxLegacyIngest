#!/usr/bin/perl

use strict;
my $DEBUG=1;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
#for security
$ENV{'PATH'}="";

$ENV{'TZ'}="GMT";

use DBI;
#connect
require "./set_connection.pl";
# re-set the db to ceiling_sums
$ENV{DBI_DSN} = "DBI:mysql:ceiling_sums:wolphin";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";
my $sth;

foreach my $model qw(RR1h_prs dev dev2 dev1320) {
foreach my $thresh qw(50 100 300) {
foreach my $fcst_len (0,1,3,6,9,12) {
foreach my $region (0,1,2) {
    my $table = "${model}_${thresh}_${fcst_len}_reg$region";
    
    # generate daily contingency table 
    $dbh->do("drop table if exists $table");

    # ORDER IS FORECAST, OBSERVATION!!
    $query = qq[
create  table $table 
select from_unixtime(1*3600*floor((o.time+1800)/(1*3600)))as time,
 sum(if(    (m.c$fcst_len < $thresh) and     (o.ceil < $thresh),1,0)) as yy,
 sum(if(    (m.c$fcst_len < $thresh) and NOT (o.ceil < $thresh),1,0)) as yn,
 sum(if(NOT (m.c$fcst_len < $thresh) and     (o.ceil < $thresh),1,0)) as ny,
 sum(if(NOT (m.c$fcst_len < $thresh) and NOT (o.ceil < $thresh),1,0)) as nn
from
ceiling.$model as m,ceiling.metars,ceiling.obs as o
where 1 = 1
and m.madis_id = metars.madis_id
and m.madis_id = o.madis_id
and m.time = o.time];
    if($region == 2) {
	$query .= qq[
# Great Lakes region (approx)
and lat >= 3800 and lat <= 4900
and lon >= -9900 and lon <= -7900];
    } elsif($region == 1) {
	$query .= qq[
# larger region for Chautauqua
and lat > 2800 and lat < 4900
and lon > -10200 and lon < -7000];
    } elsif($region == 0) {
	# otherwise, just match all the obs that match the model
    }
    
    $query .= qq[
group by time
order by time];

    if($DEBUG) {
	print "$query;\n";
    }
    print Q "$query\n;\n\n";
    $dbh->do($query);

    $query = qq[alter table $table add unique (time)];
   $dbh->do($query);
}}}}

$sth->finish();
$dbh->disconnect();
