#!/usr/local/perl5/bin/perl
# purges files more than ARGV[0] days old in various directory 

$daysOld = $ARGV[0];
if($daysOld < 21 ) {
    printf("Do you REALLY want to purge everything " .
	   "older than %d days old?\n",$daysOld);
    die "If so, rewrite this script!\n";
}

use Cwd 'chdir';  #use perl's chdir (don't know why I need to)

@dirs = ( "/data/model-a/newQcAcarsData" );
foreach $dir (@dirs) {
    chdir $dir or die "Can't chdir to $dir: $!\n";
    opendir THISDIR, "." or die "BIG problem: ";
    
    # for now, list all the files
    print "now in directory $ENV{PWD }\n";
    printf "\nPurging directory $dir \n".
	   "of files more than $daysOld days old:\n";
    while ($file = readdir THISDIR) {
	unless ($file =~ /^\./) { # don't delete hidden files
	    $mod = -M $file;
	    $create = -C $file;
	    #printf "$file mod: %4.1f, create: %4.1f\n",$mod,$create;
	    if($mod > $daysOld) {
		printf "NOT removing $file mod: %4.1f, create: %4.1f\n",
		       $mod,$create;	# 
		#unlink($file) || print("Couldn't rm $file!\n");
	    }
	}
    }				# 
    closedir THISDIR;		# 
}

