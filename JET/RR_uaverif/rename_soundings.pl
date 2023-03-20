#!/usr/bin/perl
$usage = "rename_soundings.pl <top directory to rename>\n";

$purgeDir = $ARGV[0] or die $usage;

#make this recursive

rename_directory($purgeDir);

sub rename_directory {
    my($purgeDir,$daysOld)=@_;

    opendir DIR, "$purgeDir" or die "BIG problem: $!\n";   
    printf "renaming soundings files in $purgeDir:\n";
    my @files = grep !/^\./, readdir DIR;
    print "Files are @files\n";
    foreach my $file (@files) {
	$file = "$purgeDir/$file";
	if(-d $file) {
	    #this is a directory, so...
	    rename_directory($file);
	} else {
	    # don't delete hidden files, or *.htaccess files
	    if ($file =~ /(.*)_(.*)\.gz$/) {
		my $leftside = $1;
		my $fcst_len = $2+0;
		my $newname = "${leftside}_$fcst_len.gz";
		print "$file -> $newname\n";
		rename($file,$newname) ||
		    die "cannot do it: $!";
	    }
	}
    }
    closedir DIR;
}

