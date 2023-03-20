#!/usr/bin/perl
for(my $i=-28;$i>-49;$i--) {
    system("./get_ceil_obs_all.pl $i");
}
