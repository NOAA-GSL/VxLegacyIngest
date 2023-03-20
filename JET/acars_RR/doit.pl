#!/usr/bin/perl

for(my $i=-5;$i>-24;$i--) {
    system(qq{gen_RR_acars_stats2.pl HRRR_iso $i});
    system(qq{load_acars_model_data2.pl});
}
