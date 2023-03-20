#!/usr/bin/perl

use strict;
my $DEBUG=1;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
#for security
$ENV{'PATH'}="";

$ENV{'TZ'}="GMT";

my $model = $ARGV[0];

use DBI;
#connect
require "./set_connection.pl";
my $db = "visibility_sums";
my $db_machine = $ARGV[1] || "wolphin";
# re-set the db to visibility_sums
$ENV{DBI_DSN} = "DBI:mysql:$db:$db_machine";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";

foreach my $thresh qw(50 100 300 500) { # 1/2, 1, 3, 5 miles
foreach my $fcst_len (0,1,2,3,6,9,12) {
    my @regions = qw(RUC GtLk E_US);
    if($model =~ /RR/) {
	@regions = qw(RUC GtLk E_US RR AK);
    }
foreach my $region (@regions)  {
    my $table = "${model}_${thresh}_${fcst_len}_$region";
    
    # ORDER IS FORECAST, OBSERVATION!!
    # for the RR model in the RUC region, we need to be special
    if($region eq "RUC" &&
       $model =~ /RR/) {
	$query = qq[
replace into $table (time,yy,yn,ny,nn)
select 1*3600*floor((o.time+1800)/(1*3600)) as time,
 sum(if(    (m.vis100 < $thresh) and     (o.vis100 < $thresh),1,0)) as yy,
 sum(if(    (m.vis100 < $thresh) and NOT (o.vis100 < $thresh),1,0)) as yn,
 sum(if(NOT (m.vis100 < $thresh) and     (o.vis100 < $thresh),1,0)) as ny,
 sum(if(NOT (m.vis100 < $thresh) and NOT (o.vis100 < $thresh),1,0)) as nn
from
visibility.$model as m,ceiling.metars,visibility.obs as o,ceiling.ruc_metars as rm
where 1 = 1
and m.madis_id = metars.madis_id
and m.madis_id = o.madis_id
and m.time = o.time
and m.fcst_len = $fcst_len
and m.madis_id = rm.madis_id];  #this ensures that this id is in the RUC domain

    } else {
	# things are simpler for other models
    $query = qq[
replace into $table (time,yy,yn,ny,nn)
select 1*3600*floor((o.time+1800)/(1*3600)) as time,
 sum(if(    (m.vis100 < $thresh) and     (o.vis100 < $thresh),1,0)) as yy,
 sum(if(    (m.vis100 < $thresh) and NOT (o.vis100 < $thresh),1,0)) as yn,
 sum(if(NOT (m.vis100 < $thresh) and     (o.vis100 < $thresh),1,0)) as ny,
 sum(if(NOT (m.vis100 < $thresh) and NOT (o.vis100 < $thresh),1,0)) as nn
from
visibility.$model as m,ceiling.metars,visibility.obs as o
where 1 = 1
and m.time > 1271066400
and o.time > 1271066400
and m.madis_id = metars.madis_id
and m.madis_id = o.madis_id
and m.time = o.time
and m.fcst_len = $fcst_len];
    if($region eq "GtLk") {
	$query .= qq[
# Great Lakes region (approx)
and lat >= 3800 and lat <= 4900
and lon >= -9900 and lon <= -7900];
    } elsif($region eq "E_US") {
	$query .= qq[
# larger region for Chautauqua
and lat > 2800 and lat < 4900
and lon > -10200 and lon < -7000];
    } elsif($region eq "AK") {
	$query .= qq[
# Alaska region (with some of Canada)
and lat > 5300 and lat < 7200
and lon > -17000 and lon < -12900];
    } else {
	# compare everything -- no where clause
    }
}
    $query .= qq[
group by time
order by time];

    if($DEBUG) {
	print "$query;\n";
    }
    print Q "$query\n;\n\n";
    $dbh->do($query);

}}}

$dbh->disconnect();
