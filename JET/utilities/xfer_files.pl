#!/usr/bin/perl
use strict;
my $DEBUG=1;

open(LOG,">>xfer.log") ||
    die "cannot append to xfer.log: $!";
{ my $ofh = select LOG;
  # turn off buffering for LOG
  $| = 1;
  select $ofh;
}

my $start_time = time();
print LOG "STARTING LOG at ".gmtime($start_time)."\n";

use Time::HiRes qw(usleep sleep);
use DBI;
# set connection parameters for this directory
$ENV{DBI_USER} = "moninger";
$ENV{DBI_PASS} = "wpassw";
$ENV{DBI_DSN} = "DBI:mysql:files_from_jet:wolphin";

# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $sth;
my $query="";

$query=<<"EOI";
select name from wanted_file
EOI
    ;
my $sth_wanted_file = $dbh->prepare($query);

$query =<<"EOI"
replace into files 
(name,contents)
values(?,?)
EOI
    ;
my $sth_load = $dbh->prepare($query);

my $done=0;
my $wanted_file;
my $wanted_file2;		# maybe needed in case $wanted_file gets unset after 'finish'
my $contents;
my $counter = 0;
while(!$done) {
    $contents = undef;
    $wanted_file = undef;
    $wanted_file2 = undef;
    $sth_wanted_file->execute();
    $sth_wanted_file->bind_columns(\$wanted_file2);
    $sth_wanted_file->fetch();
    $wanted_file = $wanted_file2;
    $sth_wanted_file->finish();
    if(defined $wanted_file) {
	# use an alarm here, because the file systems on jet might be hung
	use POSIX ':signal_h';
	my $mask = POSIX::SigSet->new( SIGALRM ); # signals to mask in the handler
	my $action = POSIX::SigAction->new(
					   sub { die "connect timeout" },        # the handler code ref
					   $mask,
					   # this workw with perl v5.8.8
					   );
	my $oldaction = POSIX::SigAction->new();
	sigaction( 'ALRM', $action, $oldaction );
	my $result = eval {
	    alarm(1);
	    if(-r $wanted_file) {
		open(FILE,"$wanted_file") ||
		    print LOG "could not open $wanted_file: $!";
		my $now = gmtime(time());
		print LOG "$now getting $wanted_file\n";
		$contents = undef;
		while(<FILE>) {
		    $contents .= $_;
		}
	    } else {
		# file not found
		$contents = "0";
	    }
	}; # end of eval
	alarm(0);
	sigaction( 'ALRM', $oldaction );  # restore original signal handler
	
	# process any interrupts
	if($@) {
	    if($@ =~ /timeout/) {
		$contents = "0";
		my $now = gmtime(time());
		print LOG "$now GOT TIMEOUT\n";
	    } else {
		my $now = gmtime(time());
		print LOG "$now GOT INTERRUPT (NOT TIMEOUT)\n";
		alarm(0);  # clear the still-pending alarm
		die;       # propagate unexpected exception
	    }
	}
	
	$sth_load->execute($wanted_file,$contents);
	$sth_load->finish();
	$dbh->do("delete from wanted_file");
	#print LOG "finished 'delete from wanted_file'\n";
    }
    usleep(100_000);	# microseconds (0.1 sec)
    #$counter++;
    
    #$done = 1;
}
