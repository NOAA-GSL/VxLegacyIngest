#!/usr/bin/perl
use strict;

my $DEBUG=0;

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
if($DEBUG) {
    foreach my $key (sort keys(%ENV)) {
        print "$key: $ENV{$key}\n";
    }
    print "thisDir is $thisDir\n";
    print "basename is $basename\n";
    print "\n";
}
# end useful DEBUGGING info ^^^^^^^^^^^^^^^^^
# END PREAMBLE^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

my $time = time() - 4*3600;
# get on hour boundary
$time -= $time%3600;

foreach my $fcst_len (1) {
    my $run_time = $time - 3600*$fcst_len;
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) =
	gmtime($run_time);
    $yday++;			# make it 1-based
    my $atime = sprintf("%02d%03d%02d",$year%100,$yday,$hour);
    my $command;
    $command = "./agen_madis_sites.pl dev2 $fcst_len $atime";
    print "COMMAND IS $command\n";
    system($command) &&
	die "cannot execute $command: $!";
}
