#!/usr/bin/perl

open(DEBUG,">>raob_debug.txt")||
    die "cannot open raob_debug.txt: $!";

my $raob_file_header = $ARGV[0];

my $arg = "/w3/mab/raob/intl/getraob_intl_http < ${raob_file_header}_input.tmp";
#print DEBUG "arg is $arg\n";

open(R,"$arg |") ||
    print DEBUG "problem with '$arg': $! \n";

open(OUT,"> ${raob_file_header}_output.tmp") ||
    print DEBUG "problem with opening ${raob_file_header}_output.tmp for writing: $! \n";

close(DEBUG);

my $i=0;
my $wmo_id;
my $subsequent;
my ($dum,$dum1);
while(<R>) {
    if($_ =~ s/^    254/   RAOB/) {
	if($subsequent) {
	    print "\n";
	} else {
	    $subsequent=1;
	}
	print OUT "RAOB sounding valid at:\n";
    }
    if($i == 1) {
	# get wmo_id for possible use in line 3
	($id,$dum,$dum1,$wmo_id) = split(/\s+/,$_);
	$wmo_id = sprintf("%05d",$wmo_id);
	#print "wmo_id is $wmo_id\n";
    }
    my(@stuff) = split(/\s+/,$_);
    #print "stuff is @stuff\n";
    if($stuff[1] == 3) {
	# replace '9999' with wmo_id
	$_ =~ s/ 9999/$wmo_id/;
    }
    print OUT "$_";
    $i++;
}
print OUT "\n";    

