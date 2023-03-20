#!/usr/bin/perl
use strict;

while(<>) {
    my  $in = $_;
    chomp $in;			# get rid of the final \n
    $in =~/([a-zA-Z0-9_\.\/\~,-\s]*)/;
    my $out = $1;
    print("|$in| cleaned: |$out|\n");
}
