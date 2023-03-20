#!/usr/bin/perl
use strict;
my $DEBUG=1;
use DBI;
#set database connection parameters
require "./set_connection.pl";
$ENV{DBI_DSN} = "DBI:mysql:ruc_ua:wolphin.fsl.noaa.gov";

# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});

$|=1;  #force flush of buffers after each print
open (STDERR, ">&STDOUT") || die "can't dup stdout ($!)\n";
$ENV{'PATH'}="/bin";
$ENV{CLASSPATH} =
    "/misc/whome/moninger/mysql-connector-java-5.1.6/mysql-connector-java-5.1.6-bin.jar:".
    ".";

$SIG{ALRM} = \&my_timeout;
my %month_num = (Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6,
		 Jul => 7, Aug => 8, Sep => 9, Oct =>10, Nov =>11, Dec =>12);


$ENV{'TZ'}="GMT";
my ($aname,$aid,$alat,$alon,$aelev,@description);
my ($found_airport,$lon,$lat,$lon_lat,$time);
my ($location);
my ($startSecs,$endSecs);
my ($desired_filename,$anal_dir,$fcst_len,$elev,$name,$id,$data,$bad_data);
my ($good_data,$found_sounding_data,$maps_coords,$title,$logFile);
my ($dist,$dir,$differ);
my ($loaded_soundings);
my $BAD=0;

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
use Time:Local;
#require "timelocal.pl";   #includes 'timegm' for calculations in gmt
require "./get_model_file.pl";
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
my $i_arg=0;
my $data_source = $ARGV[$i_arg++];
my $valid_time = $ARGV[$i_arg++];
my $skip_db_load = $ARGV[$i_arg++] || 0;

my $base_dir = "${data_source}_raob_site_soundings";
my $is_tmp_dir=0;
unless(-d $base_dir) {
    $base_dir = "/tmp/$$.raob_site_soundings";
    mkdir($base_dir,oct 777) ||
	die "could not mkdir $base_dir: $!";
    $is_tmp_dir=1;
}
if(-d $base_dir) {
    print "$base_dir exists\n";
} else {
    die "where is $base_dir? $!";
}

my $station_file = "$$.new_raobs.txt";
# create raobs file
my $region = 0;			# HARDWIRED FOR RUC
my $cmd = "./create_raob_file.pl $station_file $region";
open(CMD,"$cmd |") ||
    die "cannot execute $cmd: $!";
while(<CMD>) {
    print;
}
close(CMD);

# get fcst_lens for this model
my $query =<<"EOQ"
select fcst_lens from ruc_ua.fcst_lens_per_model
where model = '$data_source'
EOQ
    ;
#print "query is $query\n";
my $sth = $dbh->prepare($query);
$sth->execute();
my($fcst_lens);
$sth->bind_columns(\$fcst_lens);
unless($sth->fetch()) {
    # default fcst_lens for RUC (retro runs)
    $fcst_lens = "0,1,3,6,9,12";
}
my @fcst_lens = split(",",$fcst_lens);
print "fcst_lens are @fcst_lens\n";
foreach my $desired_fcst_len (@fcst_lens) {
    my $run_time = $valid_time -$desired_fcst_len * 3600;
    my $start = "";			# not looking for 'latest'
    
    ($desired_filename,$anal_dir,$fcst_len) =
	&get_model_file($run_time,$data_source,$DEBUG,$desired_fcst_len,
		     $start);
    if($DEBUG) {
	print "got file |$desired_filename|\n";
    }
    unless($desired_filename) {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) =
	    gmtime($run_time);
	$yday++;			# make it 1-based
	my $atime = sprintf("%02d%03d%02d",$year%100,$yday,$hour);
	#my $recipients="bill.moninger\@noaa.gov,Ming.Hu\@noaa.gov,Stephen.Weygandt\@noaa.gov";
	my $recipients="bill.moninger\@noaa.gov";
	# dereference local links, if any
	my $full_path = readlink($anal_dir) || $anal_dir;
	open MAIL,"|/usr/lib/sendmail -t";
	print MAIL<<EOI;
To: $recipients
From: RUC_verification.processing
Reply-to: Bill.Moninger\@noaa.gov
Subject: Missing $data_source file: $atime: $desired_fcst_len h fcst

$data_source run at $atime: $desired_fcst_len hour file in $full_path
is MISSING
EOI
;
	
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
	unless(open(V,"$arg 2>&1 |")) {
	    print "couldnt verify grib file: $!";
	    $BAD=1;
	}
	my($grib_nx,$grib_ny,$alat1,$elon1,$elonv,$alattan,$grib_dx,$grib_nz);
	unless($BAD) {
	    my $find_grid = 1;
    while(<V>) {
	if(/^rec 1.*:date (....)(..)(..)(..) .* anl:/) {
	    $run_year = $1;
	    $run_month_num = $2;
	    $run_mday = $3;
	    $run_hour = $4;
	    $run_fcst_len = 0;
	}
	if(/^rec 1.*:date (....)(..)(..)(..) .* (\d+)hr fcst:/) {
	    $run_year = $1;
	    $run_month_num = $2;
	    $run_mday = $3;
	    $run_hour = $4;
	    $run_fcst_len = $5;
	}
	
	if($find_grid == 1 &&
	   /Lambert Conf: Lat1 (.*) Lon1 (.*) Lov (.*)0/) {
	    $alat1 = $1;
	    $elon1 = $2;
	    $elonv = $3;
	}
	if($find_grid == 1 &&
	   /Latin1 (.*) Latin2/) {
	    $alattan = $1;
	}
	if($find_grid == 1 &&
	   /North Pole \((.*) x (.*)\) Dx (.*) Dy/) {
	    $grib_nx = $1;
	    $grib_ny = $2;
	    $grib_dx = $3;
	    $find_grid = 0;
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
	
	my($vsec,$vmin,$vhour,$vmday,$vmonth,$vyear) =
	    gmtime($valid_time);
	$vyear += 1900;
	my (@month)= qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	my $month_name = $month[$vmonth];
	my $time_line=sprintf("%-11.11s %2.2d     %2.2d      $month_name     $vyear\n",
			      $data_source,$vhour,$vmday);
	print "valid time:\n$time_line";
		
    $arg_unsafe = "${thisDir}agrib_soundings.x ".
	"$data_source $desired_filename $station_file ".
	"$alat1 $elon1 $elonv $alattan $grib_dx $grib_nx $grib_ny $grib_nz";
    $arg_unsafe =~ /([a-zA-Z0-9\.\/\~\_\-\, ]*)/;
    my $arg = $1;
    if($DEBUG) {
	print "arg is $arg\n";
    }
    open (PULL,"/usr/bin/time $arg 2>&1 |");
    $data ="";
    $name="";
    while(<PULL>) {
	if(/Begin sounding data for (\w*)/) {
	    $name = $1;
	    unless($bad_data) {
		$good_data=1;
		$found_sounding_data=1;
		$loaded_soundings++;
		$title = "";
		$data = $time_line;
	    }
	} elsif (/End sounding data/) {
	    $good_data=0;
	    $differ = "grid point $dist nm / $dir deg from $name:";
	    my $fcst_len2 = sprintf("%2.2d",$fcst_len);
	    $title = $data_source;
	    if($fcst_len == 0) {
		$title .=" analysis valid for ";
	    } else {
		$title .=" $fcst_len2 h forecast valid for ";
	    }
	    $title .= $differ;
	    my $dir = "$base_dir/$name";
	    unless(-d $dir) {
		mkdir($dir,oct 777) ||
		    print "could not mkdir $dir: $!";
	    }
	    my $sounding_file = "$dir/${valid_time}_$fcst_len";
	    if(-f "${sounding_file}.gz") {
		unlink "${sounding_file}.gz";
		print "unlinking previous ${sounding_file}.gz\n";
	    }
	    #print "writing $sounding_file\n";
	    open(F,">$sounding_file") ||
		print "cannot open $sounding_file: $!";
	    print F "$title\n";
	    print F $data;
	    close F;
	    system("gzip $sounding_file");
	} elsif (/Invalid Coordinates/) {
	    $bad_data=1;
	} elsif (/Sounding data for point/) {
	    /Sounding data for point \((.*?)\).*?\(.*? (\(.*?\))/;
	    $lon_lat=$1;
	    $maps_coords=$2;
	} elsif(/delta_east= (.*) delta_north= (.*)/) {
	    my $d_east = $1;		#
	    my $d_north = $2;
	    $dist = sqrt($d_north*$d_north + $d_east*$d_east);
	    $dist = sprintf("%.1f",$dist);
	    $dir = atan2(-$d_east,-$d_north)*57.3 + 180;
	    $dir = sprintf("%.0f",$dir);
	} elsif ($good_data) {
	    $data .= $_;
	}
	#if($DEBUG) {print;}
    }
    close PULL;
	}
    }

unless($skip_db_load == 1) {
    # now store the files in the database.
    my $command = "/opt/java/jdk1.6.0_04/bin/java Verify $base_dir $data_source ".
	"$valid_time $valid_time $desired_fcst_len";
    print "$command\n";
    system($command) &&
	print "problem with |$command|: $!";
}
}
# now clean up
unlink $station_file ||
    print "could not unlink $station_file: $!";
if($is_tmp_dir == 1) {
    if(system("/bin/rm -rf $base_dir")) {
	print "failed to remove soundings directory: $!";
    } else {
	print "removed $base_dir\n";	
    }
}
