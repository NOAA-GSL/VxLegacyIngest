#!/usr/bin/perl
for($i=-6;$i>-72;$i--) {
    my $arg = "$ENV{HOME}/ruc_madis_surface/beta/surface_driver_all_nets.pl RAP_NCEP_full $i 1\n";
    print($arg);
    system($arg);
}
    
