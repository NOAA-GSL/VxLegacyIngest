#!/usr/bin/perl -T
use strict;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $DEBUG=1;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

#for security, must set the PATH explicitly
$ENV{'PATH'}="";
use lib "./";

#get directory and URL
use File::Basename;
my ($basename,$thisDir) = fileparse($0);
$basename =~ m|([\-\~\.\w]*)|;  # untaint
$basename = $1;
$thisDir =~ m|([\-\~\.\w\/]*)|; # untaint
$thisDir = $1;

# END OF PREAMBLE ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

use DBI;
use Time::Local;

#connect
require "$thisDir/set_connection3.pl";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";
my $sth;

$query = qq[show processlist];
$sth = $dbh->prepare($query);
$sth->execute();
while(my @row = $sth->fetchrow_array()) {
    print "$row[0], $row[6]\n";
    my $id = $row[0];
    my $user = $row[1];
    my $type = $row[6];
    
    if($user eq "madis_user") {
	print "killing $id\n";
	$dbh->do(qq{kill $id});
    }
}
$sth->finish();
$dbh->disconnect();

