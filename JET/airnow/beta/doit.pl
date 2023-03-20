#!/usr/bin/perl
for (my $i=6;$i<24;$i++) {
    my $cmd = "$ENV{HOME}/sb.sh $ENV{HOME}/airnow/multiprocess_models.tcsh -$i";
    print "$cmd\n";
    system($cmd);
}
