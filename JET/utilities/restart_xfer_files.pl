#!/usr/bin/perl
use strict;
my $DEBUG=0;

#useful DEBUGGING info vvvvvvvvvvvvvv
if($DEBUG) {
    foreach my $key (sort keys(%ENV)) {
        #print "$key: $ENV{$key}<br>\n";
    }
    #print "what is this: $0\n\n";
}
my $path = $ARGV[0]; #path to script should we need to relaunch it
my $scriptName = $ARGV[1]; #name of script to look for

my $cmd = "/bin/ps aux | grep " . $scriptName;
if($DEBUG) {print "command is $cmd\n";}
my @lines = `$cmd`;

foreach(@lines) {
    #ignore results for the grep command and this script
    # $0 is the name of this script
    unless ($_  =~ m/emacs|grep|$0/){
	if($DEBUG) {print "found:$_ exiting\n";}
	exit;
    }
}

my $launchCMD = "$path/$scriptName &";
print "launching $launchCMD\n";
system($launchCMD);
