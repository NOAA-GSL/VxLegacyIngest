#!/usr/local/perl5/bin/perl
$thisDir = ".";
opendir(DIR,$thisDir) or die "can't open $thisDir: $!";
while (defined ($file = readdir DIR)) {
    if (-T "$thisDir/$file" &&
	$file =~ /.java$/) {
	open(TMP,">t") or die "Can't open t: $!";;
	print TMP <<"EOI";
package lib;
EOI
    ;
	$already_done=0;
	open(JAVA,"$thisDir/$file") or die "Can't open $thisDir/$file: $!";
	while(<JAVA>) {
	    if(m|package lib|) {
		$already_done = 1;
	    }
	    print TMP;
	}
	close(JAVA);
	close(TMP);
	unless ($already_done) {
	    print "updated $thisDir/$file\n";
	    system("/usr/bin/mv t $thisDir/$file");
	} else {
	    unlink "t";
	}
    }
}
#execute stuff here

# POSTLUDE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

#return to calling dir (this violates the Taint flag)
chdir "$callingDir" || die "Can't return to $callingDir!";

exit 0;
