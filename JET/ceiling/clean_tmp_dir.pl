sub clean_tmp_dir {
# clean up tmp directory
    opendir(DIR,"./tmp") ||
	die "cannot open tmp/: $!\n";
    my @allfiles = grep !/^\.\.?$/,readdir DIR;
    foreach my $file (@allfiles) {
	$file = "tmp/$file";
	#print "file is $file\n";
	# untaint
	$file =~ /(.*)/;
	$file = $1;
	if(-M $file > 1) {
	    print "unlinking $file\n";
	    unlink "$file" || print "Can't unlink $file $!\n";
	}
    }
    closedir DIR;
}
1;
    
