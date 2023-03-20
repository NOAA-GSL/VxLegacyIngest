#!/usr/bin/perl
use strict;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $DEBUG=1;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

#for security, must set the PATH explicitly
$ENV{'PATH'}="";
$ENV{CLASSPATH} =
    "/whome/moninger/mysql-connector-java-5.1.6/mysql-connector-java-5.1.6-bin.jar:".
    ".";
   
#get directory
use File::Basename;
my ($basename,$thisDir) = fileparse($0);
$basename =~ m|([\-\~\.\w]*)|;  # untaint
$basename = $1;
$thisDir =~ m|([\-\~\.\w\/]*)|; # untaint
$thisDir = $1;

#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
$thisDir = $ENV{PWD};

#useful DEBUGGING info vvvvvvvvvvvvvv
if($DEBUG) {
    foreach my $key (sort keys(%ENV)) {
        print "$key: $ENV{$key}\n";
    }
    print "thisDir is $thisDir\n";
    print "basename is $basename\n";
    print "\n";
}
# end useful DEBUGGING info ^^^^^^^^^^^^^^^^^
# END PREAMBLE^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

my $expname = $ARGV[0];
print "experiment name is $expname\n";

use DBI;
# set connection parameters for this directory
require "./set_connection.pl";
$ENV{DBI_DSN} = "DBI:mysql:ruc_ua_sums2:wolphin.fsl.noaa.gov";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query;

my $startSecs = 1313020800; # Thu 11 Aug 2011 00:00:00 (day 223)
my $endSecs =  1314014400; # Mon 22 Aug 2011 12:00:00 (day 234)

my $i=0;
for(my $valid_time=$startSecs;$valid_time<=$endSecs;$valid_time+=12*3600) {
    $i++;
    # see if this time has already been processed
    my ($date,$hour) = sql_date($valid_time);
    $query =
	"select distinct fcst_len from ${expname}_reg0 where date = '$date' and hour = $hour";
    my @fcsts = @{$dbh->selectcol_arrayref($query)};
    print "($i) forecasts @fcsts already processed for $date, ${hour}Z\n";
    if(@fcsts < 6) {
	my $command = "./agen_raob_sites2.pl $expname $valid_time";
	print "COMMAND IS $command\n";
	system($command) &&
	    die "cannot execute $command: $!";
    }
}
$dbh->disconnect();

sub sql_date {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return (sprintf("%4d-%2.2d-%2.2d",
                   $year,$mon,$mday),
	    $hour);
}
