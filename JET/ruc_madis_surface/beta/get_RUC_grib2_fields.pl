#!/usr/bin/perl
use strict;
my %line;
my $var;

while(<>) {
    $var="";
    if(/(MSLMA)/) {
	$var = $1;
	$line{$var}=$_;
    } elsif(/((DPT|UGRD|VGRD|TMP|RH)):(2|10) m above ground/) {
	$var = $1;
	$line{$var}=$_;
    }
}
# this ensures that the order is what we want even if NCEP changes things
foreach $var qw(MSLMA DPT UGRD VGRD TMP RH) {
    print $line{$var};
}
