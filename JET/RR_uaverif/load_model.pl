#!/usr/bin/perl
use strict;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $DEBUG=1;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

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
if($DEBUG == 2) {
    foreach my $key (sort keys(%ENV)) {
        print "$key: $ENV{$key}\n";
    }
    print "thisDir is $thisDir\n";
    print "basename is $basename\n";
    print "\n";
}
# end useful DEBUGGING info ^^^^^^^^^^^^^^^^^
# END PREAMBLE^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

my $i_arg=0;
my $expname = $ARGV[$i_arg++];
print "cycle name is $expname\n";
my $hrs_ago = $ARGV[$i_arg++]; # hours before the start of the current hour to the VALID TIME
my $time = time();
$time -= $time%3600;  # put on an hour boundary
# subtract desired number of hours to get RUN time
my $valid_time = $time - abs($hrs_ago)*3600;
my $skip_db_load = $ARGV[$i_arg++] || 0; 
my $command = "./agen_raob_sites2.pl $expname $valid_time $skip_db_load";
print "COMMAND IS $command\n";
system($command) &&
    die "cannot execute $command: $!";
