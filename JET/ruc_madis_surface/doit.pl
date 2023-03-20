#!/usr/bin/perl
my ($n_tot,$n_T,$n_Td,$n_w);
while(<>) {
    my ($dum,$name,$w_flag,$t_flag,$td_flag,$network) = split(/\s+/,$_);
    if($network eq "METAR") {
	print "$name,$w_flag,$t_flag,$td_flag,$network\n";
	$n_T += $t_flag;
	$n_Td += $td_flag;
	$n_w += $w_flag;
	$n_tot++;
    }
}
print "total: $n_tot, good wind: $n_w, good T: $n_T,  good Td: $n_Td\n";
