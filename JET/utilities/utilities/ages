#!/usr/local/perl5/bin/perl -wT


foreach $file (@ARGV) {
    $access_age = -A $file;
    $mod_age = -M $file;
    $i_age = -C $file;
    printf "%-20.20s access %8.4g, inode %8.4g, mod %8.4g\n",
    $file,$access_age,$i_age,$mod_age;
}
