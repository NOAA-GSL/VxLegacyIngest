#!/usr/bin/perl
#PBS -d .                                                                                                           
#PBS -N vis_5min_dr                                                                                                
#PBS -A amb-verif                                                                                                       
#PBS -l procs=1                                                                                                     
#PBS -l partition=tjet:sjet:vjet:xjet                                                                                              
#PBS -q service                                                                                                     
#PBS -l walltime=01:00:00                                                                                           
#PBS -l vmem=1G                                                                                                     
#PBS -M verif-amb.gsd@noaa.gov
#PBS -m a
#PBS -e tmp/                                                                                                        
#PBS -o tmp/
#
#
use strict;
my $thisDir = $ENV{PBS_O_WORKDIR};
unless($thisDir) {
    # we've been called locally instead of qsubbed
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}
my $DEBUG=1;
use Time::Local;
use DBI;

$|=1;  #force flush of buffers after each print
open (STDERR, ">&STDOUT") || die "can't dup stdout ($!)\n";
#$ENV{CLASSPATH} =
#    "/misc/ihome/moninger/javalibs/mysql/mysql-connector-java-3.1.13-bin.jar:".
#    ".";

$SIG{ALRM} = \&my_timeout;
my %month_num = (Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6,
		 Jul => 7, Aug => 8, Sep => 9, Oct =>10, Nov =>11, Dec =>12);


$ENV{'TZ'}="GMT";
my ($aname,$aid,$alat,$alon,$aelev,@description);
my ($found_airport,$lon,$lat,$lon_lat,$time);
my ($location);
my ($startSecs,$endSecs);
my ($file,$type,$fcst_len,$elev,$name,$id,$data,$bad_data);
my ($good_data,$found_sounding_data,$maps_coords,$title,$logFile);
my ($dist,$dir,$differ);
my ($loaded_soundings);
my $n_zero_vis=0;
my $n_stations_loaded=0;


#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";

use lib "./";
#require "timelocal.pl";   #includes 'timegm' for calculations in gmt
require "./get_iso_file.pl";
require "./jy2mdy.pl";
require "./update_summaries.pl";
require "./get_grid.pl";

my $usage = "usage: $0 model [hours ago] [1 to reprocess, 0 otherwise]\n";
if(@ARGV < 3) {
    print $usage;
}
if (@ARGV < 1) {
    print "too few args. Exiting.\n";
    exit;
}

my $i_arg=0;
my $data_source = $ARGV[$i_arg++];
my $hours_ago = abs($ARGV[$i_arg++]) || 0;
my $reprocess=0;
if(defined $ARGV[$i_arg++]) {
    $reprocess=1;
}

# connect to the database
$ENV{DBI_DSN} = "DBI:mysql:vis_5min:wolphin";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});

my $tmp_file = "tmp/$$.vis_5min_data.tmp";
my $data_file = "tmp/$$.loaded_5min_data.tmp";

print "hrs_ago is $hours_ago\n";
my $time = time();
# get on hour boundary
$time = $time - $time%3600 - $hours_ago*3600;
my @valid_times = ($time,$time-(0.75*3600),$time-(0.5*3600),$time-(.25*3600),$time-(3*3600),$time-(3.75*3600),$time-(3.5*3600),$time-(3.25*3600));
#my @valid_times = ($time-(0.00*3600));

# get fcst_max and interval for this model
my $query =<<"EOQ";
    select fcst_interval_min from vis_5min.model_metadata
    where model = '$data_source'
EOQ
    ;
print "model is $data_source\n";
my $fcst_interval = $dbh->selectrow_array($query);
unless($fcst_interval) {
    # default fcst_interval
    $fcst_interval = 15;
}
$query =<<"EOQ";
    select max_fcst_hour from vis_5min.model_metadata
    where model = '$data_source'
EOQ
    ;
my $fcst_max_hour = $dbh->selectrow_array($query);
#unless($fcst_max_hour) {
    # default fcst_interval
#    $fcst_max_hour = 6;
#}

my $fcst_max_min = $fcst_max_hour * 60;

# see if the needed tables exist
$dbh->do("use vis_5min");
$query = qq(show tables like "$data_source");
print "in vis_5min db: $query\n";
my $result = $dbh->selectrow_array($query);
print "result is $result\n";
unless($result) {
    # need to create the necessary tables
    $query = "create table $data_source like template";
    print "$query;\n";
    $dbh->do($query);
    # find out necessary regions
    $query =<<"EOI"
select regions from vis_5min.model_metadata where 1=1
and model = "$data_source"
EOI
;
    my @result = $dbh->selectrow_array($query);
    my @regions = split(/,/,$result[0]);
    print "regions are @regions\n";
    # find out necessary thresholds
    $query =<<"EOI"
select thresholds from vis_5min.model_metadata where 1=1
and model = "$data_source"
EOI
;
    my @result = $dbh->selectrow_array($query);
    my @thresholds = split(/,/,$result[0]);
    print "thresholds are @thresholds\n";
    $dbh->do("use vis_5min_sums");

    foreach my $region (@regions) {
        $query = "create table ${data_source}_$region like template";
        print "$query;\n";
        $dbh->do($query);
    }
}
print "fcst max min: $fcst_max_min\n";
print "fcst interval: $fcst_interval\n";
my ($min,$fcst_hr_file,$fcst_min);
$dbh->do("use vis_5min");
#foreach my $fcst_len (@fcst_lens) {
foreach my $valid_time (@valid_times) {
for ($min=0;$min<=$fcst_max_min;$min=$min+$fcst_interval) {
$fcst_min = $min%60; 
my $fcst_len = ($min - $fcst_min)/60; 
if($fcst_min == 0) {
    $fcst_hr_file = $fcst_len;
} else {
    $fcst_hr_file = $fcst_len + 1;
}
my $valid_str = gmtime($valid_time);
my $run_time = $valid_time - $fcst_len * 3600 - $fcst_min * 60;
my $valid_date = sql_datetime($valid_time);
my $str = gmtime($run_time);
print "\nRUNTIME: $str\n";

if(!$reprocess &&
   already_processed($data_source,$valid_time,$fcst_len,$fcst_min,$DEBUG)) {
    print "\nALREADY LOADED: $data_source $fcst_len h $fcst_min min fcst valid at $valid_str\n";
    next;
} else {
    print "\nTO PROCESS: $fcst_len h $fcst_min min (total $min) fcst valid at $valid_str\n";
}

if(1) {
my $start = "";			# not looking for 'latest'
($file,$type) =
    &get_iso_file3($run_time,$data_source,$DEBUG,$fcst_hr_file,$fcst_min);

my($run_year,$run_month_num,$run_mday,$run_hour,$run_fcst_len);

unless($file) {
    print "file not found for $data_source $fcst_len h $fcst_min min fcst valid at $valid_str.\n";
    next;
} else {
    print "FILE FOUND $data_source $fcst_len h $fcst_min min fcst valid at $valid_str\n";
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

my $arg_unsafe = "$thisDir/vis.x ".
    "$data_source $valid_time $file $grib_type $grid_type $tmp_file $data_file $fcst_len ".
    "$fcst_min $min $alat1 $elon1 $elonv $alattan $grib_dx ".
    "$grib_nx $grib_ny $grib_nz $DEBUG";
if($grid_type == 20 || $grid_type==21 ) {
    # rotLL grid, DETAILS ARE HARDWIRED
    $arg_unsafe = "$thisDir/rotLL_vis.x $data_source $valid_time ".
        "$file $grib_type $grid_type $tmp_file $data_file $fcst_len $fcst_min $min $DEBUG";
}
print "arg_unsafe is $arg_unsafe\n";
$arg_unsafe =~ /([a-zA-Z0-9\.\/\~\_\-\, ]*)/;
my $arg = $1;
if($DEBUG) {
    print "arg is $arg\n";
}
if(1) {
open(VIS,"$arg |") ||
    die "cannot execute $arg: $!";
while(<VIS>) {
    if($DEBUG) {print;}
    if(/(\d+) stations with zero vis/) {
	$n_zero_vis = $1;
    }
    if(/(\d+) stations loaded/) {
	$n_stations_loaded = $1;
    }
}
print "zeros: $n_zero_vis, loaded: $n_stations_loaded\n";
close VIS;

if($n_stations_loaded > 0 &&
	  $n_zero_vis < 100) {
    update_summaries($data_source,$valid_time,$fcst_len,$fcst_min,$DEBUG);
    #last source;
} else {
    print "NOT GENERATING SUMMARIES\n\n";
}}}}
} # end foreach vaild_time
unlink $tmp_file;
unlink $data_file;
print "NORMAL TERMINATION\n";
# clean up tmp directory
require "./clean_tmp_dir.pl";
clean_tmp_dir();

sub already_processed($data_source,$valid_time,$fcst_len,$DEBUG) {
    my ($data_source,$valid_time,$fcst_len,$DEBUG) = @_;
    my $query =<<"EOI"
select regions from vis_5min.model_metadata where 1=1
and model = "$data_source"
EOI
;
    my @result = $dbh->selectrow_array($query);
    my @regions = split(/,/,$result[0]);
    $query =<<"EOI"
select count(*) from vis_5min_sums.${data_source}_$regions[0]
where time = $valid_time and fcst_len = $fcst_len and fcst_min = $fcst_min
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
