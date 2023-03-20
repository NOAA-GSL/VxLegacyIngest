#!/usr/bin/perl -T
use strict;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $DEBUG=0;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

#for security, must set the PATH explicitly
$ENV{'PATH'}="";
   
#get directory
use File::Basename;
my ($basename,$thisDir) = fileparse($0);
$basename =~ m|([\-\~\.\w]*)|;	# untaint
$basename = $1;
$thisDir =~ m|([\-\~\.\w\/]*)|;	# untaint
$thisDir = $1;

#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
$thisDir = $ENV{PWD};

#useful DEBUGGING info vvvvvvvvvvvvvv
if($DEBUG) {
    foreach my $key (sort keys(%ENV)) {
    	#print "$key: $ENV{$key}\n";
    }
    print "thisDir is $thisDir\n";
    print "basename is $basename\n";
    print "\n";
}
# end useful DEBUGGING info ^^^^^^^^^^^^^^^^^
# END PREAMBLE^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
use CGI;
use DBI;
#connect
require "./set_connection.pl";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";
my $sth;

$query =<<"EOI"
update metars
set lat=?,lon=?,elev=?
where madis_id=?
EOI
    ;
my $sth_load = $dbh->prepare($query);

$query =<<"EOI"
select madis_id,name,lat,lon,elev
from metars
EOI
    ;
my $sth = $dbh->prepare($query);
$sth->execute();
my(%madis_id,%olat,%olon,%oelev);
my($madis_id,$name,$olat,$olon,$oelev);
$sth->bind_columns(\$madis_id,\$name,\$olat,\$olon,\$oelev);
while($sth->fetch()) {
    $madis_id{$name} = $madis_id;
    $olat{$name} = $olat;
    $olon{$name} = $olon;
    $oelev{$name} = $oelev;
}
$sth->finish();

open(M,"/misc/public/pub/station_tables/file/WMO/MetarTable.cfg") ||
    die "could not open ITS METAR file: $!";
my(%plat,%plon,%pelev);

while(<M>) {
    unless(/^!!/) {
	s/#//g;
	my @stuff = split;
	my $name = $stuff[0];
	$plat{$name} = round($stuff[2]*100);
	$plon{$name} = round($stuff[3]*100);
	$pelev{$name} = round($stuff[4]*3.3808);
    }
}
close(M);

my $i=0;
foreach $name (keys %madis_id) {
    if(abs($olat{$name}-$plat{$name}) ||
       abs($olon{$name}-$plon{$name}) ||
       abs($oelev{$name}-$pelev{$name})) {
	if(defined $plat{$name} &&
	   defined $plon{$name} &&
	   defined $pelev{$name}) {
	    print "$i: $name, old/new: $olat{$name}/$plat{$name}, $olon{$name}/$plon{$name}, ".
		"$oelev{$name}/$pelev{$name}\n";
	    $i++;
	    $sth_load->execute($plat{$name},$plon{$name},
			       $pelev{$name},$madis_id{$name});
	}
    }
}

sub round {
    my $result;
    my $arg = shift;
    my $iarg = int($arg);
    my $diff = $arg - $iarg;
    if($diff >= 0.5) {
	$result = $iarg+1;
    } elsif($diff <= -0.5) {
	$result = $iarg-1;
    } else {
	$result = $iarg;
    }
    return($result);
}

    
