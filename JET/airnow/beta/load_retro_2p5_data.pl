#!/usr/bin/perl

use strict;
my $DEBUG=1;

use Time::Local;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
#for security
$ENV{'PATH'}="";

$ENV{'TZ'}="GMT";

#get calling dir
my $tmp;
$tmp = $ENV{'PWD'};
#untaint it (the unsafe way!)
$tmp =~ /(.*)/;
my $callingDir = $1 || ".";

#get UNIX path for this script
#get directory
use File::Basename;
my ($basename,$thisDir) = fileparse($0);
$basename =~ m|([\-\~\.\w]*)|;  # untaint
$basename = $1;
$thisDir =~ m|([\-\~\.\w\/]*)|; # untaint
$thisDir = $1;

#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";

# clean up tmp directory
opendir(DIR,"tmp/") ||
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


my $startSecs = 1533945600;  # Sat 11 Aug 2018 00:00:00
my $endSecs = 1534896000; # Wed 22 Aug 2018 00:00:00
for(my $valid_time=$startSecs;$valid_time<=$endSecs;$valid_time+=3600) {
my($sec,$min,$hour,$mday,$mon,$year) = gmtime($valid_time);
my $time_str = sprintf("%4d%02d%02d_%02d%02d",$year+1900,$mon+1,$mday,$hour,$min);
print "time is |$time_str|\n";

my $data_dir = "airnow_old_data";
my $data_file = "$data_dir/".sprintf("%4d%02d%02d%02d.dat",$year+1900,$mon+1,$mday,$hour);

print "data_file: $data_file\n";

my $out_file = "tmp/$$.2p5.tmp";
my $result = open(my $OUT,">$out_file") ;
if($result==0) {
    print "could not open $out_file: $!";
    next;
}
$result=open(my $D,"$data_file") ;
if($result==0) {
    print "could not open $data_file: $!";
    next;
}

while(<$D>) {
    if(/PM2\.5/) {
	my @row = split(/\|/);
	#print "$_";
	#print "$row[0],$row[1],$row[2],$row[7],$row[8]\n";
	my $date = $row[0];
	my $hm = $row[1];
	my $id = $row[2];
	my $data = good_round($row[7]*10,-1e20,1e20);
	$date =~ m|(..)\/(..)\/(..)|;
	my $data_month = $1;
	my $data_mday = $2;
	my $data_year = $3+2000;
	$hm =~ m|(..)\:(..)|;
	my $data_hour = $1;
	my $data_min = $2;
	my $data_time = timegm(0,$data_min,$data_hour,$data_mday,$data_month-1,$data_year);
	my $data_time_str = gmtime($data_time);
	#print "$data_time_str, $data_time\n";
	#print "$data_time,$id,$data\n";
	print $OUT "$data_time,$id,$data\n";
    }
}
close $D;
close $OUT;

use DBI;
$ENV{DBI_DSN} = "DBI:mysql:airnow:wolphin.fsl.noaa.gov;mysql_local_infile=1";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1, PrintError => 1}) or
    exit(1);
my $sth;
my $query;

$query =<<"EOI"
load data concurrent local infile '$out_file'
replace into table retro_obs2p5 columns terminated by ','
(time,id,pm2p5_10)
EOI
    ;
print "$query;\n";
my $rows = $dbh->do($query);
print"$rows rows inserted into obs2p5 (dups count double)\n";
show_warnings($dbh,$query);

unlink($out_file) ||
    die "could not unlink $out_file: $!";
}

sub show_warnings {
    my($dbh,$query) = @_;
    my $warnings = $dbh->selectall_arrayref('SHOW WARNINGS');
    if(@$warnings > 0) {
	print "warnings for $query\n";
	for my $row (@$warnings) {
	    print "@$row\n";
	}
    }
}	    

sub good_round {
    my ($arg,$min,$max) = @_;
    my $i_arg = '\N';
    if(defined $arg &&
       $arg <= $max &&
       $arg >= $min) {
	$i_arg = int($arg);
	my $dif = $arg - $i_arg;
	if($dif > 0.5) {
	    $i_arg++;
	} elsif($dif < -0.5) {
	    $i_arg--;
	}
    }
    return $i_arg;
}
