#!/usr/bin/perl
use strict;
use DBI;
#set database connection parameters
$ENV{DBI_DSN} = "DBI:mysql:acars_RR:wolphin.fsl.noaa.gov;mysql_local_infile=1";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1, PrintWarn => 1});

my $query=<<"EOI"
select aid,xid,unix_timestamp(date),press from acars
 where 1=1
and date >= '2013-05-29 00:00:00'
and date <  '2013-06-05 00:00:00'
order by aid,date
EOI
;
my %data;
print "$query;\n";
my $sth = $dbh->prepare($query);
my($aid,$xid,$secs,$press);
$sth->execute();
$sth->bind_columns(\$aid,\$xid,\$secs,\$press);
while($sth->fetch()) {
    #print "$aid,$xid,$secs,$press\n";
    $data{$xid}{$secs} = {aid => $aid, press => $press}; # a reference to a hash
}
$sth->finish();

my $pid = $$;
my $tmp_file = "$pid.vvel.tmp";
open(D,">$tmp_file") ||
    die "could not open $tmp_file";
foreach my $xid (keys %data) {
    my $last_secs=0;
    my $last_press = 0;
    my $last_aid = 0;
    foreach my $secs (sort keys %{$data{$xid}}) {
	my $time_str = gmtime($secs);
	my $delta_secs = $secs - $last_secs;
	if($last_secs == 0) {
	    $delta_secs = undef;
	}
	my $press = $data{$xid}{$secs}->{press};
	my $delta_p = $press - $last_press;
	if($last_press == 0) {
	    $delta_p = undef;
	}
	my $vvel = undef;
	if(defined $delta_secs && $delta_secs < 600) {
	    $vvel = $delta_p/$delta_secs * 10; # pascals per second
	} else {
	    $vvel = undef;
	    $last_aid = undef;
	}
	my $aid = $data{$xid}{$secs}->{aid};
	#print "$xid, $time_str,$press,$vvel,$delta_p,$delta_secs,$aid\n";
	print(D "$aid,".code_nulls($vvel).",".code_nulls($last_aid)."\n");
	$last_press = $press;
	$last_secs = $secs;
	$last_aid = $aid;
    }
}
close(D);

$query=<<"EOI"
load data concurrent local infile '$tmp_file'
replace into table acars_RR.vvel columns terminated by ','
(aid,vvel,last_aid)
EOI
    ;
print "$query";
my $rows = $dbh->do($query);
print_warn($dbh);
print "$rows rows affected\n\n";
unlink $tmp_file ||
    die "could not unlink $tmp_file: $!";
 
sub code_nulls {
    my $val = shift;
    my $result = '\\N';
    if(defined $val) {
	$result = $val;
    }
    return $result;
}

sub print_warn {
    my $dbh = shift;
    my $warnings = $dbh->selectall_arrayref('SHOW WARNINGS');
    for my $row (@$warnings) {
	print "@{$row}\n";
    }
}
