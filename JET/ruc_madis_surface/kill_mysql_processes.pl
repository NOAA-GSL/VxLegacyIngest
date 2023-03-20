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
    #print "@row\n";
    my $id = $row[0];
    my $user = $row[1];
    my $command = $row[4];
    my $time = $row[5];
    my $type = $row[6];
    
    if($user eq "wcron0_user" &&
       $command eq "Sleep" &&
       $time > 100) {
	print "killing $id\n";
	$dbh->do(qq{kill $id});
    }
}
$sth->finish();
$dbh->disconnect();

