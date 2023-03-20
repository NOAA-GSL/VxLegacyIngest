#!/usr/bin/perl
use strict;
my $DEBUG=1;

$|=1;  #force flush of buffers after each print
open (STDERR, ">&STDOUT") || die "can't dup stdout ($!)\n";
$ENV{'PATH'}="/bin";
$ENV{CLASSPATH} =
    "/misc/ihome/moninger/javalibs/mysql/mysql-connector-java-3.1.13-bin.jar:".
    ".";

$SIG{ALRM} = \&my_timeout;
my %month_num = (Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6,
		 Jul => 7, Aug => 8, Sep => 9, Oct =>10, Nov =>11, Dec =>12);


$ENV{'TZ'}="GMT";
my ($aname,$aid,$alat,$alon,$aelev,@description);
my ($found_airport,$lon,$lat,$lon_lat,$time);
my ($location);
my ($startSecs,$endSecs);
my ($file,$type,$fcst_len,$elev,$name,$id,$data,$bad_data);
my ($good_data,$found_sounding_data,$maps_coords,$title,$logFile);
my ($dist,$dir,$differ);
my ($loaded_soundings);

#get directory and URL
use File::Basename; 
my ($basename,$thisDir,$thisURLDir,$returnAddress,$apts,$line);
($basename,$thisDir) = fileparse($0);
($basename,$thisURLDir) = fileparse($ENV{'SCRIPT_NAME'} || '.');
#untaint
$thisDir =~ /([a-zA-Z0-9\.\/\~\_]*)/;
$thisDir = $1;
$basename =~ /([a-zA-Z0-9\.\/\~\_]*)/;
$basename = $1;
$thisURLDir =~ /([a-zA-Z0-9\.\/\~\_]*)/;
$thisURLDir = $1;

#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";

use lib "./";
require "timelocal.pl";   #includes 'timegm' for calculations in gmt
use DBI;

#get best return address
$returnAddress = "(Unknown-Requestor)";
if($ENV{REMOTE_HOST}) {
    $returnAddress = $ENV{REMOTE_HOST};
} else {
    # get the domain name if REMOTE_HOST is not set
    my $addr2 = pack('C4',split(/\./,$ENV{REMOTE_ADDR}));
    $returnAddress = gethostbyaddr($addr2,2) || $ENV{REMOTE_ADDR};
}

require "./set_connection.pl";
# re-set the db to visibility_sums
$ENV{DBI_DSN} = "DBI:mysql:visibility_sums:wolphin";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});

my $query = qq[show tables];
my $sth = $dbh->prepare($query);
$sth->execute();
my $table;
$sth->bind_columns(\$table);
while($sth->fetch()) {
    #print "checking  $table\n";
    my $sth_check = $dbh->prepare("check table $table");
    $sth_check->execute();
    my $ref;
    while($ref = $sth_check->fetchrow_hashref()) {
	print "$$ref{Table} $$ref{Msg_type} $$ref{Msg_text}\n";
	if($$ref{Msg_type} eq "error") {
	    print "repairing $table\n";
	    my $sth_repair = $dbh->prepare("repair table $table");
	    $sth_repair->execute();
	    while($ref = $sth_repair->fetchrow_hashref()) {
		print "$$ref{Table} $$ref{Msg_type} $$ref{Msg_text}\n";
	    }
	    last;
	}
    }
}

    
    
