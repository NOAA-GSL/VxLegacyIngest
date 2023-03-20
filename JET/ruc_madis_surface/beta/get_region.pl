#!/usr/bin/perl

use strict;
my $DEBUG=1;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
#for security
$ENV{'PATH'}="";

$ENV{'TZ'}="GMT";

require "./w3fb11.pl";

use DBI;
#connect
require "./set_connection.pl";
# re-set the db to ceiling_sums
$ENV{DBI_DSN} = "DBI:mysql:madis3:wolphin";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";

$query=<<"EOI"
select madis_id,lat/100,lon/100,reg
from metars2
EOI
    ;
my($id,$lat,$lon,$reg);
my $sth = $dbh->prepare($query);
$sth->execute();
$sth->bind_columns(\$id,\$lat,\$lon,\$reg);

$query=<<"EOI";
update metars2
set reg = ?
where madis_id = ?
EOI
    ;
my $sth_update = $dbh->prepare($query);

my $region = "NHX_W";
my $alat1= 38.75254;
my $elon1= -89.8269;
my $dx= 3000;
my $elonv= -100.;
my $alatan= 41.69 ;
my $nx= 541;
my $ny= 346;

while($sth->fetch()) {
    #my ($xi,$yj) = w3fb11($lat,$lon,$alat1,$elon1,$dx,$elonv,$alatan);
    if($lat >= 20 && ($lon < 0 || $lon > 180)) {
	#print "$id,$lat,$lon,|$reg| => $xi,$yj\n";
	unless($reg =~ /$region/) {
	    $reg = join(',',($region,$reg));
	    print "$id, $lat, $lon, reg: $reg\n";
	    $sth_update->execute($reg,$id);
	}
    }
}
