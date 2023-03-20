#!/usr/bin/perl
use strict;

for(my $i=-2;$i>-24;$i--) {
    system("agen_airport_sites_db.pl Bak13 $i");
}
