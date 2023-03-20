#!/usr/bin/perl -T
use strict;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $DEBUG=0;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

#for security, must set the PATH explicitly
$ENV{'PATH'}="";

use CGI::Carp qw(fatalsToBrowser);
use CGI;
    
#get directory and URL
use File::Basename;
my ($dum,$thisDir) = fileparse($ENV{SCRIPT_FILENAME} || '.');
$thisDir =~ m|([\-\~\.\w\/]*)|;	# untaint
$thisDir = $1;
my ($basename,$thisURLDir) = fileparse($ENV{'SCRIPT_NAME'} || '.');
$basename =~ m|([\-\~\.\w]*)|;	# untaint
$basename = $1;
$thisURLDir =~ m|([\-\~\.\w\/]*)|;	# untaint
$thisURLDir = $1;

#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";

#get best return address
my $returnAddress = "(Unknown-Requestor)";
if($ENV{REMOTE_HOST}) {
    $returnAddress = $ENV{REMOTE_HOST};
} else {
    # get the domain name if REMOTE_HOST is not set
    my $addr2 = pack('C4',split(/\./,$ENV{REMOTE_ADDR}));
    $returnAddress = gethostbyaddr($addr2,2) || $ENV{REMOTE_ADDR};
}
#connect
use DBI;
require "./set_writer_acars_RR.pl";
$ENV{DBI_DSN} = "DBI:mysql:acars_RR:wolphin";
my $dbh = DBI->connect(undef,undef,undef, {PrintError => 1});
my $query = "";
my $sth;

for(my $secs =  1436140800; # 6 July 2015
    $secs > 1430438400; #1 May 2015
    $secs -= (24*3600)) {
    my $start_date = sql_date($secs);
    my $end_date = sql_date($secs + 24*3600);
    $query=<<"EOI"
insert ignore into acars3
select * from acars
where 1=1
and date >= '$start_date'
and date < '$end_date'
EOI
;
    print "$query\n";
    $sth = $dbh->prepare($query);
    $sth->execute();
    $sth->finish();
    sleep(2);			# let other users of acars get some work done
}
    
sub sql_date {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
		   $year,$mon,$mday,$hour,$min,$sec);
}
  
