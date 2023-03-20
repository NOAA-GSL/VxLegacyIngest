#!/usr/bin/perl -T
use strict;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $DEBUG=1;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

#for security, must set the PATH explicitly
$ENV{'PATH'}="";
use lib "./";

#get directory and URL
use File::Basename;
my ($basename,$thisDir) = fileparse($0);
$basename =~ m|([\-\~\.\w]*)|;  # untaint
$basename = $1;
$thisDir =~ m|([\-\~\.\w\/]*)|; # untaint
$thisDir = $1;

# END OF PREAMBLE ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

use DBI;
use Time::Local;
my $table = $ARGV[0];
my $n_days = abs($ARGV[1]);
if($n_days == 0) {
    print "usage: $0 <db.table> <number of days to keep>\n";
    exit;
}

#connect
$ENV{DBI_DSN} = "DBI:mysql::wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "writer";
$ENV{DBI_PASS} = "amt1234";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 0, PrintError => 1});
my $query = "";
my $rows;

# get current time
my $now_time = time();
my $drop_time = $now_time - $n_days*24*3600;
my $new_time = $now_time +3*24*3600; # three days hence

# delete partition(s)
$query = "show create table $table";
my @result = $dbh->selectrow_array($query);
my @lines = split(/\n/,$result[1]);
foreach my $line (@lines) {
    if($line =~ /PARTITION d(....)(..)(..)/) {
	my $partition_year = $1;
	my $partition_month = $2;
	my $partition_day = $3;
	my $partition_time = timegm(0,0,0,$partition_day,$partition_month-1,$partition_year);
	my $partition_name = sprintf("d$partition_year%02d%02d",
				     $partition_month,$partition_day);
	if($partition_time <= $drop_time) {
	    $query = "alter table $table drop partition $partition_name";
	    print "$query\n";
	    $dbh->do($query);
	} else {
	    print "NOT dropping partition $partition_name\n";
	}
    }
}

# add new partition
my $new_date = sql_date($new_time);
my $new_date_no_dash = $new_date;
$new_date_no_dash =~ s/-//g;
my $new_partition_name = sprintf("d%s",$new_date_no_dash);
$query = "alter table $table  add partition ".
    "(partition $new_partition_name values less than ".
    "(to_days('$new_date')))";
print "$query\n";
$dbh->do($query);

sub sql_date {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d",
		   $year,$mon,$mday);
}
