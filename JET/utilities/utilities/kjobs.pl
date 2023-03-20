#!/usr/bin/perl
if($ENV{OSTYPE} eq 'solaris') {
    open(PS,"/bin/ps -ef|");
} else {
    open(PS,"/bin/ps -efww|");
}
while(<PS>) {
    unless( defined $ARGV[0]) {
	die "need an argument: a string in the process name(s) to terminate\n";
    }
    if(/$ARGV[0]/ && /$ENV{LOGNAME}/) {
	# don't kill this process
	unless(/kjobs/) {
	    ($dum,$id) = split;
	    print "killing $id\n";
	    system("kill $id");
	}
    }
}
