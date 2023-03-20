#!/usr/bin/perl
use strict;
my $DEBUG=1;

$|=1;  #force flush of buffers after each print
open (STDERR, ">&STDOUT") || die "can't dup stdout ($!)\n";
$ENV{'PATH'}="/bin";
$ENV{CLASSPATH} =
    "/misc/ihome/moninger/javalibs/mysql/mysql-connector-java-3.1.13-bin.jar:".
    ".";

$SIG{ALRM} = \&my_timeout;
my %month_num = (Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6,
		 Jul => 7, Aug => 8, Sep => 9, Oct =>10, Nov =>11, Dec =>12);


$ENV{'TZ'}="GMT";
my ($aname,$aid,$alat,$alon,$aelev,@description);
my ($found_airport,$lon,$lat,$lon_lat,$time);
my ($location);
my ($startSecs,$endSecs);
my ($desired_filename,$type,$fcst_len,$elev,$name,$id,$data,$bad_data);
my ($good_data,$found_sounding_data,$maps_coords,$title,$logFile);
my ($dist,$dir,$differ);
my ($loaded_soundings);

#get directory and URL
use File::Basename; 
my ($basename,$thisDir,$thisURLDir,$returnAddress,$apts,$line);
($basename,$thisDir) = fileparse($0);
($basename,$thisURLDir) = fileparse($ENV{'SCRIPT_NAME'} || '.');
#untaint
$thisDir =~ /([a-zA-Z0-9\.\/\~\_]*)/;
$thisDir = $1;
$basename =~ /([a-zA-Z0-9\.\/\~\_]*)/;
$basename = $1;
$thisURLDir =~ /([a-zA-Z0-9\.\/\~\_]*)/;
$thisURLDir = $1;

#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";

use lib "./";
use Time::Local;
#require "timelocal.pl";   #includes 'timegm' for calculations in gmt
require "./get_surface_file.pl";
require "./jy2mdy.pl";

#get best return address
$returnAddress = "(Unknown-Requestor)";
if($ENV{REMOTE_HOST}) {
    $returnAddress = $ENV{REMOTE_HOST};
} else {
    # get the domain name if REMOTE_HOST is not set
    my $addr2 = pack('C4',split(/\./,$ENV{REMOTE_ADDR}));
    $returnAddress = gethostbyaddr($addr2,2) || $ENV{REMOTE_ADDR};
}

my $data_source = $ARGV[0];
my $desired_fcst_len = $ARGV[1];
my $atime = $ARGV[2];
my $db_machine = $ARGV[3];
my $db_name = $ARGV[4];

$atime =~ /(..)(...)(..)/;
my $year = $1 + 2000;
my $jday = $2;
my $hour = $3;
my ($dum,$mday,$month_name) = jy2mdy($jday,$year);
my $run_time = timegm(0,0,$hour,$mday,$month_num{$month_name}-1,$year);

my $valid_time = $run_time +$desired_fcst_len * 3600;

my $start = "";			# not looking for 'latest'
($desired_filename,$type,$fcst_len) =
    &get_surface_file($valid_time,$data_source,$DEBUG,$desired_fcst_len,
		    $start);
if($DEBUG) {
    print "got file $desired_filename of type $type\n";
}

my($run_year,$run_month_num,$run_mday,$run_hour,$run_fcst_len);

if($desired_filename) {
    my $arg_unsafe =
	"${thisDir}col_wgrib.x -V $desired_filename";
    $arg_unsafe =~ /([a-zA-Z0-9\.\/\~\_\-\, ]*)/;
    my $arg = $1;
    if($DEBUG) {
	print "arg is $arg\n";
    }
    open(V,"$arg 2>&1 |") ||
	die "couldnt verify grib file: $!";
    my($grib_nx,$grib_ny,$alat1,$elon1,$elonv,$alattan,$grib_dx,$grib_nz);
    $grib_nz = 1;
    while(<V>) {
	if(/:date (....)(..)(..)(..) .* anl:$/) {
	    $run_year = $1;
	    $run_month_num = $2;
	    $run_mday = $3;
	    $run_hour = $4;
	    $run_fcst_len = 0;
	}
	if(/:date (....)(..)(..)(..) .* (\d+)hr fcst:$/) {
	    $run_year = $1;
	    $run_month_num = $2;
	    $run_mday = $3;
	    $run_hour = $4;
	    $run_fcst_len = $5;
	}
	
	if(/Lambert Conf: Lat1 (.*) Lon1 (.*) Lov (.*)0/) {
	    $alat1 = $1;
	    $elon1 = $2;
	    $elonv = $3;
	}
	if(/Latin1 (.*) Latin2/) {
	    $alattan = $1;
	}
	if(/North Pole \((.*) x (.*)\) Dx (.*) Dy/) {
	    $grib_nx = $1;
	    $grib_ny = $2;
	    $grib_dx = $3;
	}
	if(/hybrid lev (\d+) /) {
	    if($1 > $grib_nz) {
		$grib_nz = $1;
	    }
	}
    }
    close(V);
				     
    if($DEBUG) {
	print "|$alat1| |$elon1| |$elonv| |$alattan| ".
	    "|$grib_nx| |$grib_ny| |$grib_dx| nz = |$grib_nz|\n";
	print ("run times from file: $run_year,$run_month_num,$run_mday,".
	       "$run_hour,$run_fcst_len\n");
    }
    my $valid_time_from_file = timegm(0,0,$run_hour,$run_mday,
				      $run_month_num - 1,
				      $run_year) + 3600*$run_fcst_len;
    if($valid_time_from_file != $valid_time) {
	print "BAD VALID TIME from file: $valid_time_from_file\n";
	exit(1);
    }
    $arg_unsafe = "${thisDir}agrib_madis_sites.x $db_machine $db_name ".
	"$data_source $valid_time $desired_filename $desired_fcst_len ".
	"$alat1 $elon1 $elonv $alattan $grib_dx ".
	"$grib_nx $grib_ny $grib_nz $DEBUG";
    $arg_unsafe =~ /([a-zA-Z0-9\.\/\~\_\-\, ]*)/;
    my $arg = $1;
    if($DEBUG) {
	print "arg is $arg\n";
    }
    unless(system($arg)==0) {
	print "trouble executing $arg: $!\n";
    }

}
