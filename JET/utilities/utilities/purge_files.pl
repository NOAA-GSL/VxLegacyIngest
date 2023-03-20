#!/usr/bin/perl
# purges files in directory ARGV[0], AND SUBDIRECTORIES
# more than ARGV[1] days old 
# ARGV[0] must be an absolute path
# uses perl's 'readdir' to avoid limit of number of items in '*'

$usage = "purge_files.pl <directory to purge> <min age in days to purge>\n";

$purgeDir = $ARGV[0] or die $usage;
$daysOld = $ARGV[1] or  die $usage;

#make this recursive

purge_directory($purgeDir,$daysOld);

sub purge_directory {
    my($purgeDir,$daysOld)=@_;

    opendir DIR, "$purgeDir" or die "BIG problem: $!\n";   
    printf "Purging files more than $daysOld days old in $purgeDir:\n";
    my @files = grep !/^\./, sort readdir DIR;
    #print "Files are @files\n";
    foreach my $file (@files) {
	$file = "$purgeDir/$file";
	if(-d $file) {
	    #this is a directory, so...
	    $mod = -M $file;
	    print "age of  directory $file is $mod\n";
	    purge_directory($file,$daysOld);
	} else {
	    # don't delete hidden files, or *.htaccess files
	    unless ($file =~ /^\./ || $file =~ /.htaccess/) { 
		$mod = -M $file;
		#printf "$ENV{PWD}/$file, %4.1f days old\n",$mod;
		if($mod > $daysOld) {
		    printf " removing $file, %4.1f days old\n", $mod;
		    unlink($file) || print("Couldn't rm $file!\n");
		}
	    }
	}				
	closedir DIR;
    }
}


