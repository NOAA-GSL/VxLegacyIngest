#!/usr/bin/perl
# purges files in directory ARGV[0], AND SUBDIRECTORIES
# more than ARGV[1] days old 
# ARGV[0] must be an absolute path

# see Perl Cookbook, by Christiansen and Torkington, p 325
use File::Find qw(finddepth);
$ussage = "usage: $0  <directory to purge> <min age in days to purge>\n" unless $ARGV;
$purgeDir = $ARGV[0] or die $usage;
$daysOld = $ARGV[1] or die $usage;
*file = *File::Find::name;
finddepth(\&zap,$purgeDir);

sub zap {
    if(!-l && -d _) {
	# for a directory, if it is too old, remove it.
	# (finddepth guarantees all the contents will be visited first)
	$mod = -M $file;
	#print "directory $file is $mod days old\n";
	if($mod > $daysOld) {
	    print "removing directory $file ($mod days old)\n";
	    rmdir($file) or warn "conldn't rmdir $file: $!";
	}
    } else {
	# don't delete hidden files, or *.htaccess files
	unless ($file =~ /^\./ || $file =~ /.htaccess/) { 
	    $mod = -M $file;
	    #printf "$ENV{PWD}/$file, %4.1f days old\n",$mod;
	    if($mod > $daysOld) {
		printf " removing $file, %4.1f days old\n", $mod;
		unlink($file) or warn("Couldn't unlink $file: $!");
	    }
	}

    }
}
	
	
