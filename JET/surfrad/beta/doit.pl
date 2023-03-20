#!/usr/bin/perl
use strict;
for(my $i=-7;$i >-24;$i--) {
    system("./multiprocess_models.py $i");
    print "running load_surfrad.py\n";
    system("./load_surfrad.py");
}

    
