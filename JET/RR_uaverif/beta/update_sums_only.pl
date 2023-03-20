#!/usr/bin/perl
use strict;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $DEBUG=1;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

#for security, must set the PATH explicitly
$ENV{'PATH'}="";
$ENV{TZ} = "GMT";
$ENV{CLASSPATH} =
    "/misc/ihome/moninger/javalibs/mysql/mysql-connector-java-3.1.13-bin.jar:".
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

my $start_secs = abs($ARGV[0]);
my $end_secs = $ARGV[1];

if($start_secs < 315532800) { # 1/1/1980
    # assume ARGV[0] is number of 12 h periods ago
    my $n12 = $start_secs;
    my $secs = time();
    $secs = $secs - $secs%(12*3600); # nearest previous 12h period
    $secs -= $n12*(12*3600);
    $start_secs = $secs;
    $end_secs = $start_secs;
}

my $arg = "/usr/bin/java UpdateSumsRR $start_secs $end_secs";
print "$arg\n";
system($arg) &&
    die "problem with command: $!";
