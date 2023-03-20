#!/usr/bin/perl
use strict;

for(my $i=20;$i<60;$i++) {
    system("gen_persis.pl -$i 0");
}
