#!/usr/bin/perl
use strict;
print "usage: get_ceil_obs_backfill.pl <startSecs> <endSecs.\n";
my $startSecs = $ARGV[0];
my $endSecs = $ARGV[1];
if($startSecs == 0 || $endSecs == 0) {
    exit(1);
}
for( my $secs = $startSecs;$secs <= $endSecs; $secs += 3600) {
    my $arg = "./get_ceil_obs_backfill_hour.pl $secs";
    print "$arg\n";
    system($arg);
}

