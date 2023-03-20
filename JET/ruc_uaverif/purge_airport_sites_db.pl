#!/usr/bin/perl
use strict;
my $DEBUG=1;
#for security, must set the PATH explicitly
$ENV{'PATH'}="";
   
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
if(0) {
    foreach my $key (sort keys(%ENV)) {
        print "$key: $ENV{$key}\n";
    }
    print "thisDir is $thisDir\n";
    print "basename is $basename\n";
    print "\n";
}
# end useful DEBUGGING info ^^^^^^^^^^^^^^^^^
# END PREAMBLE^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
use DBI;
#set database connection parameters
require "./set_connection.pl";
$ENV{DBI_DSN} = "DBI:mysql:soundings:wolphin.fsl.noaa.gov";

# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $sth;
my $query="";

my $days_ago = $ARGV[0];
unless($days_ago) {
    print "usage: purge_airport_sites_db.pl days_ago\n";
    exit;
}
my $min_secs_to_keep = time() - $days_ago*24*3600;
my $min_time_to_keep = sql_datetime($min_secs_to_keep);

$query =<<"EOI"
delete from model_airport_soundings
    where time < '$min_time_to_keep'
EOI
    ;
if($DEBUG) {
    print "query is $query\n";
}
my $result;
$result = $dbh->do($query);
print "$result soundings deleted\n";
exit(0);

sub sql_datetime {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
		   $year,$mon,$mday,$hour,$min,$sec);
}

