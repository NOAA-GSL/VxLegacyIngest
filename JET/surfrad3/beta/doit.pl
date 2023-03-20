#!/usr/bin/perl
use strict;
for(my $i=-6;$i >-48;$i--) {
    system("./gen_surfrad.tcsh $i");
    #print "running load_surfrad.tcsh\n";
    system("./load_surfrad.py");
}

    
