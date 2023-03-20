#!/usr/bin/perl

for($i=-5;$i>-24;$i--) {
    my $arg = "./process_precip_mesonets2.py 12 $i";
    print "$arg\n";
    system($arg);
    $arg = "./load_mysql2.py";
    print "$arg\n";
    system($arg);
}
