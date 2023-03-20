#!/usr/local/perl5/bin/perl
# purges files more than ARGV[0] days old in various directory 

$daysOld = $ARGV[0];
if($daysOld < 21 ) {
    printf("Do you REALLY want to purge everything " .
	   "older than %d days old?\n",$daysOld);
    die "If so, rewrite purgeHourlyPrecip.pl!\n";
}
		    
@dirs = ( "/data/mab/moninger/ncacars/www_operational/test_output");
foreach $dir (@dirs) {
    unless (chdir($dir)) {
	print "Can't chdir to $dir\n";
	next;
    }
# for now, list all the files
    print "\nPurging directory $dir \nof files more than $daysOld days old:\n";
    while ($file = <*>) {
	$mod = -M $file;
	$create = -C $file;
	printf "$file mod: %4.1f, create: %4.1f\n",$mod,$create;
	if($mod > $daysOld) {
	    printf "removing $file mod: %4.1f, create: %4.1f\n",$mod,$create;
	    unlink($file) ||
		print("Couldn't rm $file!\n");
	}			
    }
}
