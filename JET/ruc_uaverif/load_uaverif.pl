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

print "valid time is $start_secs\n";

my @models = qw(Bak13);
#@models = qw[FIM];
print "models are @models\n";

foreach my $model (@models) {
    my $directory = "${model}_raob_site_soundings";
    my $mod_start_secs = $start_secs;
    my $mod_end_secs = $end_secs;
    # FIM arrives late
    if($model eq "FIM") {
	$mod_start_secs = $start_secs - 12*3600;
	$mod_end_secs = $start_secs - 12*3600;
    }
    system("/usr/bin/java Verify $directory $model $mod_start_secs $mod_end_secs") &&
	die "problem with command: $!";
}
unlink $raob_input_file  ||
    die "cannot unlink $raob_input_file: $!";
unlink $raob_output_file  ||
    die "cannot unlink $raob_output_file: $!";
