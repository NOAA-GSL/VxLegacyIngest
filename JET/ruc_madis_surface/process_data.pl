#!/usr/bin/perl
use strict;

my $startSecs = 1174251600;
my $endSecs = 1174420800;
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday);

for(my $time=$startSecs;$time<$endSecs;$time+=12*3600) {
    foreach my $fcst_len (0,1,3,6,9,12) {
	my $run_time = $time - 3600*$fcst_len;
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) =
	    gmtime($run_time);
	$yday++;			# make it 1-based
	my $atime = sprintf("%02d%03d%02d",$year%100,$yday,$hour);
	my $command = "./agen_madis_sites.pl dev2 0 $atime";
	print "COMMAND IS $command\n";
	system($command) &&
	    die "cannot execute $command: $!";
    }
}
