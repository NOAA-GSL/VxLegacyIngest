#!/usr/bin/perl
use strict;

my $dir = "mesonet_uselists";
opendir(DIR,$dir) ||
    die "cannot open $dir: $!";
my @list = grep !/^\.\.?$/, readdir(DIR);

foreach my $file (reverse @list) {
    #print "$dir/$file\n";
    open(G,"grep METAR $dir/$file|wc|");
    my $date = $file;
    $date =~ s/_meso_uselist.txt//;
    while(<G>) {
	my @stuff = split;
	print "$date good METARs: $stuff[0]\n";
    }
    close G;
}

    


    
