#!/usr/bin/perl
use strict;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $DEBUG=0;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

#for security, must set the PATH explicitly
$ENV{'PATH'}="";
$ENV{TZ} = "GMT";
$ENV{CLASSPATH} =
    "/usr/local/apps/netscape/java:".
    "/usr/local/apps/JMF/lib:".
    "/w3/mysql/mysql-connector-java-3.1.13-bin.jar:".
    "/w3/unidata_toolsUI/toolsUI-2.2.14.jar:".
    ".";
$ENV{raob_file_header} = "raob$$";
my $raob_input_file = "$ENV{raob_file_header}_input.tmp";
my $raob_output_file = "$ENV{raob_file_header}_output.tmp";

   
#get directory
use File::Basename;
my ($basename,$thisDir) = fileparse($0);
$basename =~ m|([\-\~\.\w]*)|;	# untaint
$basename = $1;
$thisDir =~ m|([\-\~\.\w\/]*)|;	# untaint
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
my $time = time();
$time -= $time%3600;	# put on an hour boundary
# subtract desired number of hours to get VALID time
# must be on a 12 hr boundry, else the needed files won't be there
my $start_secs = $time - abs($ARGV[0])*3600;
# process only this valid time
my $end_secs = $start_secs + 1;	# add one second

if(1 == 1) {
    # load RAOBs
system("/usr/bin/java Verify RAOB 0 $start_secs $end_secs") &&
    die "problem with command: $!";
unlink $raob_input_file  ||
    die "cannot unlink $raob_input_file: $!";
unlink $raob_output_file  ||
    die "cannot unlink $raob_output_file: $!";

    # load models
system("/usr/bin/java Verify dev2 0 $start_secs $end_secs") &&
    die "problem with command: $!";
} else {
system("/usr/bin/java Verify dev2 1 $start_secs $end_secs") &&
    die "problem with command: $!";
system("/usr/bin/java Verify dev2 3 $start_secs $end_secs") &&
    die "problem with command: $!";
system("/usr/bin/java Verify dev2 6 $start_secs $end_secs") &&
    die "problem with command: $!";
system("/usr/bin/java Verify dev2 9 $start_secs $end_secs") &&
    die "problem with command: $!";
system("/usr/bin/java Verify dev 0 $start_secs $end_secs") &&
    die "problem with command: $!";
system("/usr/bin/java Verify dev 1 $start_secs $end_secs") &&
    die "problem with command: $!";
system("/usr/bin/java Verify dev 3 $start_secs $end_secs") &&
    die "problem with command: $!";
system("/usr/bin/java Verify dev 6 $start_secs $end_secs") &&
    die "problem with command: $!";
system("/usr/bin/java Verify dev 9 $start_secs $end_secs") &&
    die "problem with command: $!";
system("/usr/bin/java Verify Bak20 0 $start_secs $end_secs") &&
    die "problem with command: $!";
system("/usr/bin/java Verify Bak20 1 $start_secs $end_secs") &&
    die "problem with command: $!";
system("/usr/bin/java Verify Bak20 3 $start_secs $end_secs") &&
    die "problem with command: $!";
system("/usr/bin/java Verify Bak20 6 $start_secs $end_secs") &&
    die "problem with command: $!";
system("/usr/bin/java Verify Bak20 9 $start_secs $end_secs") &&
    die "problem with command: $!";
system("/usr/bin/java Verify Op20 0 $start_secs $end_secs") &&
    die "problem with command: $!";
system("/usr/bin/java Verify Op20 1 $start_secs $end_secs") &&
    die "problem with command: $!";
system("/usr/bin/java Verify Op20 3 $start_secs $end_secs") &&
    die "problem with command: $!";
system("/usr/bin/java Verify Op20 6 $start_secs $end_secs") &&
    die "problem with command: $!";
system("/usr/bin/java Verify Op20 9 $start_secs $end_secs") &&
    die "problem with command: $!";
}



