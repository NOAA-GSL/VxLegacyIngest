#!/usr/bin/perl
#SBATCH -J vis_driver
#SBATCH --mail-user=verif-amb.gsl@noaa.gov                                                                                          
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service 
#SBATCH -t 02:00:00
#SBATCH --mem=1G
#SBATCH -D .
#SBATCH -e /home/amb-verif/visibility/tmp/vis_driver.e%j
#SBATCH -o /home/amb-verif/visibility/tmp/vis_driver.o%j
#
#

use strict;
my $thisDir = $ENV{SLURM_SUBMIT_DIR};
unless($thisDir) {
    # we've been called locally instead of qsubbed
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}

my $DEBUG=1;

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
my ($startSecs,$endSecs);
my ($file,$type,$fcst_len,$elev,$name,$id,$data,$bad_data);
my ($good_data,$found_sounding_data,$maps_coords,$title,$logFile);
my ($dist,$dir,$differ);
my ($loaded_soundings);


#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
print "current directory is now $ENV{PWD}\n";
print "Content-type: text/html\n\n<pre>";
#foreach my $key (sort keys(%ENV)) {
#    print "$key: $ENV{$key}<br>\n";
#}

use lib "./";
use Time::Local;
#require "timelocal.pl";   #includes 'timegm' for calculations in gmt
require "./jy2mdy.pl";
require "./update_summaries2.pl";
require "./get_iso_file_backfill.pl";
require "./get_grid.pl";
use DBI;
#connect
require "./set_connection.pl";
my $dbh = DBI->connect(undef,undef,undef, {PrintError => 1});

my $retro=0;
my $i_arg=0;
my $data_source = $ARGV[$i_arg++];
my $startSecs = $ARGV[$i_arg++];
my $endSecs = $ARGV[$i_arg++];
my $model_name_for_metadata = $data_source;
my $reprocess=0;
if(defined $ARGV[$i_arg++]) { 
    $reprocess=1;
}

# get fcst_lens for this model
my $query =<<"EOQ"
    select fcst_lens from visibility.fcst_lens_per_model
    where model = '$model_name_for_metadata'
EOQ
    ;
print "model is $data_source\n";
my $sth = $dbh->prepare($query);
$sth->execute();
my($fcst_lens);
$sth->bind_columns(\$fcst_lens);
unless($sth->fetch()) {
    # default fcst_lens for RR (retro runs)
         $fcst_lens = "-99,0,1,3,6,9,12";
}
my @fcst_lens = split(",",$fcst_lens);
#@fcst_lens = (1,2);
print "fcst_lens are @fcst_lens\n";

# find out necessary regions
$query =<<"EOI"
select regions_name from visibility.regions_per_model where 1=1
and model = "$model_name_for_metadata"
EOI
;
my @result = $dbh->selectrow_array($query);
my @regions = split(/,/,$result[0]);
#@regions = ("ALL_HRRR");
print "regions are @regions\n";

# find necessary thresholds
$query =<<"EOI"
select thresholds from visibility.thresholds_per_model where 1=1
and model = "$model_name_for_metadata"
EOI
;
my @result = $dbh->selectrow_array($query);
my @thresholds = split(/,/,$result[0]);
print "thresholds are @thresholds\n";

# see if the needed tables exist
$dbh->do("use visibility");
$query = qq(show tables like "$data_source");
print "in visibility db: $query\n";
my $result = $dbh->selectrow_array($query);
print "result is $result\n";
unless($result) {
    # need to create the necessary tables
    $query = "create table $data_source like template";
    print "$query;\n";
    $dbh->do($query);
    $dbh->do("use visibility_sums2");
    foreach my $region (@regions) {
        $query = "create table ${data_source}_$region like template";
        print "$query;\n";
        $dbh->do($query);
    }
}

for(my $valid_time=$startSecs;$valid_time<=$endSecs;$valid_time+=1*3600) {
    my $valid_time_str = gmtime($valid_time);
    print("processing all forecast lengths for $valid_time_str\n");
    my @processed_fcst_lens=();
foreach $fcst_len (@fcst_lens) {
    if(!$reprocess && already_processed($data_source,$valid_time,$fcst_len,\@regions,$dbh)) {
	my $s = gmtime($valid_time);
	print "$data_source $fcst_len h fcst valid at $s already processed\n";
	next;
    }
    my $trouble = 0;

my $run_time = $valid_time - $fcst_len * 3600;

my $start = "";			# not looking for 'latest'
($file,$type) =
    &get_iso_file($run_time,$data_source,$DEBUG,$fcst_len,
		    $start);
if($file) {
    $trouble=0;
} else {
    $trouble=1;
}
if($DEBUG) {
    print "got file $file of type $type\n";
}
my($run_year,$run_month_num,$run_mday,$run_hour,$run_fcst_len);

unless($file) {
    print "file not found.\n";
    next;
}
# get grid details
# get grid details
my($la1,$lo1,$lov,$latin1,$nx,$ny,$dx,$grib_type,$grid_type,$valid_date,$fcst_proj,$wind_rot_flag)
    = get_grid($file,$thisDir,$DEBUG);

    print "valid_date $valid_date.\n";

my($valid_year,$valid_month_num,$valid_mday,$valid_hour) = $valid_date =~ /(....)-(..)-(..) (..)/;
# change 'undef' to zeros for use in the $arg_unsafe argument list
$la1+=0;
$lo1+=0;
$lov+=0;
$latin1+=0;
$nx+=0;
$ny+=0;
$dx+=0;
$grid_type+=0;
my $nz = 1;
    # hard wire $dy and $dx for now, since wgrib2 -grid appears to be broken
    # for dx an dy
if($dx == 0 &&
   $la1 != 0) {
    if($nx == 451) {
	$dx = 13545.087;
    } elsif($nx == 301) {
	$dx = 20317.625;
    } elsif($nx == 151) {
	$dx = 40635.25;
    }
}

# convert dx to km
$dx/=1000;
if(1) {
    print "grib_type is $grib_type, grid is $grid_type |$la1| |$lo1| |$lov| |$latin1| ".
	"|$nx| |$ny| |$dx|\n";
    print ("valid times from get_grid: $valid_year,$valid_month_num,$valid_mday,".
	   "$valid_hour,$fcst_proj\n");
}
my $valid_time_from_file = timegm(0,0,$valid_hour,$valid_mday,
				  $valid_month_num - 1,
				  $valid_year);
if($valid_time_from_file != $valid_time) {
    print "BAD VALID TIME from file: $valid_time_from_file\n";
    exit(1);
}

my $tmp_file = "tmp/$$.grib2_data.tmp";

if($grib_type == 2) {
my $arg =
    "wgrib2 -v $file |".
    "grep 'VIS' |".
    "wgrib2 -order raw -i -text $tmp_file $file >/dev/null 2>&1";
if($DEBUG) {
    print "arg is $arg\n";
}
unless(system($arg)==0) {
    die "trouble executing $arg: $!\n";
}
if(-z $tmp_file) {
    die "field 'VIS' not found in $file. Stopping.\n";
}
}

my $arg_unsafe = "$thisDir/vis.x ".
    "$data_source $valid_time $file $grib_type $grid_type $tmp_file $fcst_len ".
    "$la1 $lo1 $lov $latin1 $dx ".
    "$nx $ny $nz $DEBUG";
$arg_unsafe =~ /([a-zA-Z0-9\.\/\~\_\-\, ]*)/;
my $arg = $1;
if($DEBUG) {
    print "arg is $arg\n";
}
my $exit_code = system($arg) >> 8;
#print("exit code is $exit_code\n");
if($exit_code == 3) {
    # no observations available for this valid time.
    print("No obs available for $valid_time_str\n");
    last;
} elsif($exit_code != 0) {
    print "trouble executing $arg: $!\n";
    $trouble = 1;
    exit(1);
} else {
    push(@processed_fcst_lens,$fcst_len);
}
if($grib_type == 2) {
    unlink($tmp_file) ||
	die "could not unlink $tmp_file: $!";
}
}				# end loop over forecast lens
update_summaries2($data_source,$valid_time,\@processed_fcst_lens,\@regions,\@thresholds,$DEBUG);
}				# end loop over valid times
# clean up tmp directory
my $purge_time_days = $ENV{vis_purge_time_days}+0; # convert to a number
print("purging files in tmp directory older than $purge_time_days days\n");
if($purge_time_days == 0) {
    die "bad purge_time_days: |$purge_time_days|\n";
}
opendir(DIR,"tmp") ||
    die "cannot open tmp/: $!\n";
my @allfiles = grep !/^\.\.?$/,readdir DIR;
foreach my $file (@allfiles) {
    $file = "tmp/$file";
    #print "file is $file\n";
    # untaint
    $file =~ /(.*)/;
    $file = $1;
    if(-M $file > $purge_time_days) {
	print "unlinking $file\n";
	unlink "$file" || print "Can't unlink $file $!\n";
    }
}
closedir DIR;
print "NORMAL EXIT\n";

sub already_processed {
    my($data_source, $valid_time,$fcst_len,$regions_ptr,$dbh) = @_;
    my @regions = @$regions_ptr;
    my $query =<<"EOI";
select count(*) from visibility_sums2.${data_source}_$regions[0]
where 1=1
and time = $valid_time
and fcst_len = $fcst_len
EOI
;
    #print "$query\n";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my($n);
    $sth->bind_columns(\$n);
    $sth->fetch();
    #print "n returned is $n\n";
    return $n;
}
    


