#!/usr/bin/perl

use strict;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

#for security, must set the PATH explicitly
$ENV{'PATH'}="/usr/bin";
    
#get directory and URL
use File::Basename;
my ($dum,$thisDir) = fileparse($0);
$thisDir =~ m|([-~.\w/]*)|;	# untaint
$thisDir = $1;

#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
print "this_dir is $thisDir\n";

use lib "/misc/whome/moninger/DBD-mysql-2.9004/lib";
use lib "/misc/whome/moninger/DBD-mysql-2.9004/blib/arch/auto/DBD/mysql";
use DBI;
#set database connection parameters
require "./set_connection.pl";
$ENV{DBI_DSN} = "DBI:mysql:ruc_ua_pb:wolphin.fsl.noaa.gov";

# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});

my $out_file = $ARGV[0];
my $region = $ARGV[1];

my $reg_matcher = 2**$region;

if (!defined ($out_file)) {
  print ("create_raob_file.pl outFileName\n");
  exit;
};
print "IN CREATERAOB: DIR OUTFILE: $thisDir/$out_file\n";
#######################!!!!!!!!!!!!!!!!!!!!!!!! PUT BACK?????
#open(OUT,">$thisDir/$out_file") ||
open(OUT,">$out_file") ||
    die "Cannot open $thisDir/$out_file: $!";
print "opening $out_file\n";

my $query =<<"EOQ"
select wmoid, name, lat, lon, elev,descript 
 from ruc_ua_pb.metadata where
 reg & $reg_matcher = $reg_matcher
 order by name
EOQ
    ;
print "query is $query\n";
my $sth = $dbh->prepare($query);
$sth->execute();
my($wmoid,$name,$lat,$lon,$elev,$descript);
$sth->bind_columns(\$wmoid,\$name,\$lat,
		   \$lon,\$elev,\$descript);
while($sth->fetch()) {
    printf(OUT "0000 %5.5s %d %6.2f %6.2f %4d %s\n",
	   $name,$wmoid,$lat/100.0,$lon/100.0,$elev,$descript);
}
$sth->finish();
$dbh->disconnect();
