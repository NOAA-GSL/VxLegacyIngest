#!/usr/bin/perl
use strict;

open(D,"ls -lath tmp/*.out.* | head -45|");
while(<D>) {
    print;
    my @stuff = split;
    my $file= $stuff[$#stuff];
    system("tail -1 $file");
}
