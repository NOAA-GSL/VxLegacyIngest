#!/usr/bin/perl
$i=0;
$j=0;
while(<>) {
    @items = split(/\,/,$_);
    #print "items list: @items\n";
    foreach $item (@items) {
	my $printit = 0;
	if($item =~ /1/) {
	    $item = 1.0;
	    $printit = 1;
	} elsif($item =~ /0/) {
	    $item = 16;
	    $printit = 1;
	}
	if($printit) {
	    printf("%5.2f ",$item);
	    $j++;
	    if($i++ >= 16) {
		print "\n";
		$i=0;
	    }
	}
    }
}

print "\n$j items printed\n";
