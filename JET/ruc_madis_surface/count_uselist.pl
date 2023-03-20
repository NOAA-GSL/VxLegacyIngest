#!/usr/bin/perl
#

my ($n_w,$n_T,$n_Td,$n_tot);

while(<>) {
    if(/^;/) {
	# comment line
	next;
    }
    my($name,$use_w,$use_T,$use_Td,$net) = split;
    if($net ne "METAR") {
	$n_w += $use_w;
	$n_T += $use_T;
	$n_Td += $use_Td;
	$n_tot++;
    }
}
#my $n_avail = 2863; # METARs
my $n_avail = 22015; # non-METARs
my $w_pct = $n_w/$n_avail * 100;
my $T_pct = $n_T/$n_avail * 100;
my $Td_pct = $n_Td/$n_avail * 100;

printf( "non-METARs n_w: $n_w (%.0f%%), n_T: $n_T (%.0f%%), n_Td: $n_Td (%.0f%%), total on uselist: $n_tot, ".
	"total stations: $n_avail\n",
	$w_pct,$T_pct,$Td_pct);

    
	
