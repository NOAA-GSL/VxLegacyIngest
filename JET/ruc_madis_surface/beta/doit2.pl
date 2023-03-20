#!/usr/bin/perl
for($i=-60;$i<-6;$i++) {
    my $arg = "$ENV{HOME}/ruc_madis_surface/beta/surface_driver_q1.pl RR1h $i 0 METAR";
    print($arg);
    system($arg);
}
    
