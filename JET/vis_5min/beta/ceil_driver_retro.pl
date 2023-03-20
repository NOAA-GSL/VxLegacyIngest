#!/usr/bin/perl
use strict;
my $thisDir = $ENV{PBS_O_WORKDIR};
my $qsubbed = 1;
unless($thisDir) {
    # we've been called locally instead of qsubbed
    $qsubbed = 0;
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}
my $output_id = $ENV{PBS_JOBID} || $$;

my $DEBUG=1;

use Time::Local;
use DBI;

$|=1;  #force flush of buffers after each print
open (STDERR, ">&STDOUT") || die "can't dup stdout ($!)\n";
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
my ($startSecs,$endSecs,$query,$retro_temp);
my ($file,$type,$elev,$name,$id,$data,$bad_data);
my ($good_data,$found_sounding_data,$maps_coords,$title,$logFile);
my ($dist,$dir,$differ);
my ($loaded_soundings);
my $n_zero_ceilings=0;;
my $n_stations_loaded=0;


#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";

use lib "./";
#require "timelocal.pl";   #includes 'timegm' for calculations in gmt
require "./get_iso_file.pl";
require "./jy2mdy.pl";
require "./update_summaries_retro.pl";
require "./clean_tmp_dir.pl";
require "./get_grid.pl";
require "./gen_retro_tables.pl";

my $data_source = $ARGV[0];
my $startSecs = $ARGV[1];
my $endSecs = $ARGV[2];
my $reprocess = $ARGV[3] || 0;

print "|$data_source|, $startSecs\n";

unless ($data_source) {
    print "usage: ceil_driver_retro.pl {exp_name} <start_secs> <end_secs> [1 = reprocess]\n";
    exit(1);
}
if($qsubbed == 1) {
    my $output_file = "tmp/$data_source.ret_dvr.out.$output_id";
# send standard out (and stderr) to $output_File
    use IO::Handle;
    *STDERR = *STDOUT;          # send standard error to standard out
    open OUTPUT, '>',"$output_file" or die $!;
    STDOUT->fdopen( \*OUTPUT, 'w' ) or die $!; # send stdout to output file
}

# connect to the database
$ENV{DB_NAME} = "wolphin.fsl.noaa.gov"; # needed for the C code
$ENV{DBI_DSN} = "DBI:mysql:ceiling2:$ENV{DB_NAME}";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});

# create the needed tables
gen_retro_tables($data_source,$dbh,$DEBUG);

my $tmp_file = "tmp/$$.ceiling_data.tmp";
my $data_file = "tmp/$$.loaded_data.tmp";

my $retro_temp = "";
if ($data_source =~ /AK/) {
   $retro_temp = "AK_retro";
} elsif ($data_source =~ /HRRR/) {
   $retro_temp = "HRRR_retro";
} else {
   $retro_temp = "RAP_retro";
}
# find our necessary fcst lengths
$query =<<"EOI"
select fcst_lens from ceiling2.fcst_lens_per_model where 1=1
and model = "$retro_temp"
EOI
;
my @result = $dbh->selectrow_array($query);
my @fcst_lens = split(/,/,$result[0]);

for(my $valid_time = $startSecs;$valid_time <= $endSecs;$valid_time += 3600) {
my $valid_str = gmtime($valid_time);
my $valid_date = sql_datetime($valid_time);
foreach my $fcst_len (@fcst_lens) {
my $run_time = $valid_time - $fcst_len * 3600;

if(!$reprocess &&
   already_processed($data_source,$valid_time,$fcst_len,$DEBUG)) {
    print "\nALREADY PROCESSED: $data_source $fcst_len h fcst valid at $valid_str\n";
    next;
} else {
    #print "\nTO PROCESS: $fcst_len h fcst valid at $valid_str\n";
}

my $start = "";			# not looking for 'latest'
($file,$type) =
    &get_iso_file3($run_time,$data_source,$DEBUG,$fcst_len,
		    $start);

my($run_year,$run_month_num,$run_mday,$run_hour,$run_fcst_len);

unless($file) {
    print "file not found for $data_source $fcst_len h fcst valid at $valid_str.\n";
    next;
} else {
    print "FILE FOUND $data_source $fcst_len h fcst valid at $valid_str\n";
}
# get grid details
my($alat1,$elon1,$elonv,$alattan,$grib_nx,$grib_ny,$grib_dx,
   $grib_type,$grid_type,$valid_date_from_file,$fcst_len_from_file) =
    get_grid($file,$thisDir,$DEBUG);
my $grib_nz = 1;	# not needed for 2d files
if($valid_date_from_file != $valid_date) {
    print "BAD VALID DATE from file: $valid_date_from_file\n";
    exit(1);
}

my $arg_unsafe = "$thisDir/ceil_retro.x ".
    "$data_source $valid_time $file $grib_type $grid_type $tmp_file $data_file $fcst_len ".
    "$alat1 $elon1 $elonv $alattan $grib_dx ".
    "$grib_nx $grib_ny $grib_nz $DEBUG";


if($grid_type == 20 || $grid_type==21 ) {
    # rotLL grid, DETAILS ARE HARDWIRED
    $arg_unsafe = "$thisDir/rotLL_ceil_retro.x $data_source $valid_time ".
	"$file $grib_type $grid_type $tmp_file $data_file  $fcst_len $DEBUG";
}
$arg_unsafe =~ /([a-zA-Z0-9\.\/\~\_\-\, ]*)/;
my $arg = $1;
if($DEBUG) {
    print "arg is $arg\n";
}
open(CEIL,"$arg |") ||
    die "cannot execute $arg: $!";
while(<CEIL>) {
    if($DEBUG) {print;}
    if(/(\d+) stations with zero ceilings/) {
	$n_zero_ceilings = $1;
    }
    if(/(\d+) stations loaded/) {
	$n_stations_loaded = $1;
    }
}
print "zeros: $n_zero_ceilings, loaded: $n_stations_loaded\n";
close CEIL;

if($n_stations_loaded > 0 &&
   $n_zero_ceilings < 100) {
    update_summaries_retro($data_source,$valid_time,$fcst_len,$DEBUG);
} else {
    print "NOT GENERATING SUMMARIES\n\n";
}
}}
unlink $tmp_file;
unlink $data_file;
print "NORMAL TERMINATION\n";
clean_tmp_dir();

sub already_processed($data_source,$valid_time,$fcst_len,$DEBUG) {
    my ($data_source,$valid_time,$fcst_len,$DEBUG) = @_;
    my $retro_temp = "";
    if ($data_source =~ /HRRR/) {
      $retro_temp = "HRRR_retro";
    } elsif ($data_source =~ /AK/) {
      $retro_temp = "AK_retro";
    } else {
      $retro_temp = "RAP_retro";
    }
    $query =<<"EOI"
select regions_name from ceiling2.regions_per_model where 1=1
and model = "$retro_temp"
EOI
;
    my @result = $dbh->selectrow_array($query);
    my @regions = split(/,/,$result[0]);
    my $query =<<"EOI"
select count(*) from ceiling_sums2.${data_source}_$regions[0]
where time = $valid_time
and fcst_len = $fcst_len
EOI
;
    #if($DEBUG) {print "query is $query\n";}
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my($n);
    $sth->bind_columns(\$n);
    $sth->fetch();
    #print "n returned is $n\n";
    return $n;
}

sub sql_datetime {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
		   $year,$mon,$mday,$hour,$min,$sec);
}

