#!/usr/bin/perl

for($i=-5;$i>-120;$i--) {
    my $arg = "./make_precip.pl $i";
    print "$arg\n";
    system($arg);
}
