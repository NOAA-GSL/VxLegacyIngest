#!/usr/bin/perl
#
#  Set the name of the job.
#$ -N load_model
#  Make sure that the .e and .o file arrive in the working directory
#$ -cwd
#
#  Set the account
#$ -A nrtrr
#
#  Ask for 1 cpus of type service
#$ -pe service 1
#
#  My code is re-runnable
#$ -r y
#
# send mail on abort, end
#$ -m a
#$ -M Susan.R.Sahm@noaa.gov
#
#  The max walltime 
#$ -l h_rt=01:00:00
#
#$ -e tmp/
#$ -o /dev/null
#
use strict;
$|=1;  #force flush of buffers after each print
open (STDERR, ">&STDOUT") || die "can't dup stdout ($!)\n";
my $thisDir = $ENV{SGE_O_WORKDIR};
unless($thisDir) {
    # we've been called locally instead of qsubbed
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}
my $output_id = $ENV{JOB_ID} || $$;
my $DEBUG=1;

#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
$thisDir = $ENV{PWD};

#useful DEBUGGING info vvvvvvvvvvvvvv
if(0) {
    foreach my $key (sort keys(%ENV)) {
        print "$key: $ENV{$key}\n";
    }
    print "thisDir is $thisDir\n";
    print "\n";
}
# end useful DEBUGGING info ^^^^^^^^^^^^^^^^^
# END PREAMBLE^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
use DBI;
#set database connection parameters
require "./set_connection.pl";
$ENV{DBI_DSN} = "DBI:mysql:soundings:wolphin.fsl.noaa.gov";

# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $sth;
my $query="";
$query =<<"EOI"
replace into model_airport_soundings 
(model,site,time,fcst_len,s,hydro)
values(?,?,?,?,?,?)
EOI
    ;
my $sth_load = $dbh->prepare($query);
my $gzipped_sounding="";
my $gzipped_hydro="";
my $sql_date;
use Compress::Zlib;

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

use lib "./";
use Time::Local;
#require "timelocal.pl";   #includes 'timegm' for calculations in gmt
require "./get_model_file.pl";
require "./jy2mdy.pl";

my $i_arg=0;
my $data_source = $ARGV[$i_arg++];
my $hrs_ago = $ARGV[$i_arg++]; # hours before the start of the current hour to the VALID TIME
my $output_file = "tmp/airports.$data_source.$output_id.out";
# send standard out (and stderr, see above) to $output_File
use IO::Handle;
open OUTPUT, '>',"$output_file" or die $!;
STDOUT->fdopen( \*OUTPUT, 'w' ) or die $!;

my $time = time();
$time -= $time%3600;  # put on an hour boundary
# subtract desired number of hours to get VALID time
my $valid_time = $time - abs($hrs_ago)*3600;

my $station_file = "airports.txt";
# create airport file
my $cmd = "./create_airport_file.pl $station_file";
open(CMD,"$cmd |") ||
    die "cannot execute $cmd: $!";
while(<CMD>) {
    print;
}
close(CMD);

# for airports, store anx and 3h forecasts only
my $fcst_lens = "0,3";
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
	my $recipients="bill.moninger\@noaa.gov";
	# dereference local links, if any
	my $full_path = readlink($anal_dir) || $anal_dir;
	open MAIL,"|/usr/lib/sendmail -t";
	print MAIL<<EOI;
To: $recipients
From: $data_source.airport.processing
Reply-to: Bill.Moninger\@noaa.gov
Subject: Missing $data_source file: $atime: $desired_fcst_len h fcst (amb-verif on jet)

$data_source run at $atime: $desired_fcst_len hour file in $full_path
is MISSING
EOI
;
	
    }

    my($run_year,$run_month_num,$run_mday,$run_hour,$run_fcst_len);
    
    if($desired_filename) {
	my $arg_unsafe =
	    "$thisDir/col_wgrib.x -V $desired_filename";
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
		
    $arg_unsafe = "$thisDir/agrib_soundings.x ".
	"$data_source $desired_filename $station_file ".
	"$alat1 $elon1 $elonv $alattan $grib_dx $grib_nx $grib_ny $grib_nz hydro";
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
	    my $un_gzipped = "$title\n$data";
	    $gzipped_sounding = Compress::Zlib::memGzip($un_gzipped) ||
		die "cannot do memGzip for sounding data: $!\n";
	    $sql_date = sql_datetime($valid_time);
	} elsif(/Begin hydrometeor data for (\w*)/) {
	    if($1 ne $name) {
		die "big problem for hydro data: $1 ne $name\n";
	    }
	    $data="";
	    $good_data=1;
	} elsif(/End hydrometeor data/) {
	    $good_data = 0;
	    my $hydro_length = length($data);
	    if($hydro_length == 0) {
		$gzipped_hydro = undef;
	    } else {
		$gzipped_hydro = Compress::Zlib::memGzip($data) ||
		die "cannot do memGzip for hydro data: $!\n";
	    }
	    print "$name $fcst_len $sql_date (hydro: $hydro_length)\n";
	    $sth_load->execute($data_source,$name,$sql_date,$fcst_len,
			       $gzipped_sounding,$gzipped_hydro);
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
}

# now clean up
#unlink $station_file ||
#    print "could not unlink $station_file: $!";
# clean up tmp directory
opendir(DIR,"tmp") ||
    die "cannot open tmp/: $!\n";
my @allfiles = grep !/^\.\.?$/,readdir DIR;
foreach my $file (@allfiles) {
    $file = "tmp/$file";
    #print "file is $file\n";
    # untaint
    $file =~ /(.*)/;
    $file = $1;
    if(-M $file > .5) {
	print "unlinking $file\n";
	unlink "$file" || print "Can't unlink $file $!\n";
    }
}
closedir DIR;
print "NORMAL TERMINATION\n";

sub sql_datetime {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
		   $year,$mon,$mday,$hour,$min,$sec);
}
