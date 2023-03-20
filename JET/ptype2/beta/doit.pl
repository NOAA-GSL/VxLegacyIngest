#!/usr/bin/perl
for(my $i=-5;$i>-24;$i--) {
    print "PROCESSING $i hours ago\n";
    system("multiprocess_HRRR2.py $i");
    print "LOADING DATA\n";
    system("load_ptype2.py");
}
