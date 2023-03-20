#!/usr/bin/perl
for(my $i=-5;$i> -24;$i--) {
    system("./vis_driver.pl HRRR  $i");
    system("./vis_driver.pl HRRR_OPS  $i");
    system("./vis_driver.pl RTMA_GSD  $i");
    system("./vis_driver.pl RTMA_GSD_dev1  $i");
    system("./vis_driver.pl RTMAv2_6_EMC  $i");
}
