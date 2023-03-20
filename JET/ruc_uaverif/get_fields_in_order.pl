#!/usr/bin/perl
use strict;
my %HoH;
my $var;
my $lev;
#$HoH{""}{""}=1;
# don't bother with CAPE and CIN
my @var_list = qw(HGT TMP RH UGRD VGRD);
while(<>) {
    chomp;
    $var="";
    $lev="";
    if(/((HGT|TMP|RH|UGRD|VGRD)):(\d+) (hybrid|mb)/) {
	$var = $1;
	$lev = $3;
   } elsif(/(CAPE):255-0 mb above ground:/) {
	$var = $1;
	$lev = 255;
    } elsif(/(CIN):255-0 mb above ground:/) {
	$var = $1;
	$lev = 255;
    }
    # all this efforts because fields apparently appear twice in the analysis
    # files.  This takes the first appearence of each field/level combination
    # (at least this happened for GFS data, maybe not in Op20)
    unless($HoH{$var}{$lev}) {
	#print;
	$HoH{$var}{$lev} = $_;
    }
 }
foreach my $var (@var_list) {
    foreach my $lev (sort {$b - $a} keys %{$HoH{$var}}) {
	my $val_out = $HoH{$var}{$lev};
	print "$HoH{$var}{$lev}\n";
    }
}

