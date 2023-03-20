#!/usr/bin/perl

for(my $i=-3;$i>-48;$i--) {
    system(qq{gen_RR_acars_stats2.pl RAP_iso $i});
    system(qq{gen_RR_acars_stats2.pl HRRR_iso $i});
    system(qq{load_acars_model_data3.pl});
}
