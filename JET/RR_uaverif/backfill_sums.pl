#!/usr/bin/perl
#
#PBS -d .                                                                                                           
#PBS -N a_r_st3
#PBS -A amb-verif                                                                                                       
#PBS -l procs=1                                                                                                     
#PBS -l partition=tjet:sjet:vjet:xjet                                                                                              
#PBS -q service                                                                                                     
#PBS -l walltime=01:00:00                                                                                           
#PBS -l vmem=16G                                                                                                     
#PBS -e tmp/                                                                                                        
#PBS -o tmp/
#
use strict;
my $thisDir = $ENV{PBS_O_WORKDIR};
my $qsubbed=1;
unless($thisDir) {
    # we've been called locally instead of qsubbed
    $qsubbed=0;
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}
my $output_id = $ENV{PBS_JOBID} || $$;

my $DEBUG=1;
use DBI;


#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
$thisDir = $ENV{PWD};

#set database connection parameters
require "./set_connection.pl";
$ENV{DBI_DSN} = "DBI:mysql:soundings:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "UA_realtime";
$ENV{DBI_PASS} = "newupper";

$ENV{model_sounding_file} = "tmp/model_sounding.$$.tmp";

# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $sth;
my $query="";
my $gzipped_sounding="";
my $gzipped_hydro="";
my $sql_date;
use Compress::Zlib;

$|=1;  #force flush of buffers after each print
$ENV{CLASSPATH} =
    '/home/amb-verif/javalibs/mysql-connector-java-5.1.6/mysql-connector-java-5.1.6-bin.jar:'.
    ".";

$SIG{ALRM} = \&my_timeout;
my %month_num = (Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6,
		 Jul => 7, Aug => 8, Sep => 9, Oct =>10, Nov =>11, Dec =>12);


$ENV{'TZ'}="GMT";
my ($aname,$aid,$alat,$alon,$aelev,@description);
my ($found_airport,$lon,$lat,$lon_lat,$time);
my ($location);
my ($startSecs,$endSecs);
my ($desired_filename,$out_file,$fcst_len,$elev,$name,$id,$data,$bad_data);
my ($good_data,$found_sounding_data,$maps_coords,$title,$logFile);
my ($dist,$dir,$differ);
my ($loaded_soundings);
my $BAD=0;
my $all_levels_filled = 0;
my($alat1,$elon1,$elonv,$alattan,$grib_nx,$grib_ny,$grib_nz,$grib_dx,
   $grib_type,$grid_type,$valid_date_from_file,$fcst_len_from_file);
my $tmp_file = "tmp/$$.data.tmp";

use lib "./";
use Time::Local;
#require "timelocal.pl";   #includes 'timegm' for calculations in gmt
require "./get_RR_file_refill.pl";
require "./jy2mdy.pl";
require "./get_grid.pl";
#require "./record_residuals.pl";

#get best return address
my $returnAddress = "(Unknown-Requestor)";
if($ENV{REMOTE_HOST}) {
    $returnAddress = $ENV{REMOTE_HOST};
} else {
    # get the domain name if REMOTE_HOST is not set
    my $addr2 = pack('C4',split(/\./,$ENV{REMOTE_ADDR}));
    $returnAddress = gethostbyaddr($addr2,2) || $ENV{REMOTE_ADDR};
}
my $usage = "usage: $0 model [startSecs] [endSecs] [1 to reprocess, 0 otherwise]\n";
if(@ARGV < 3) {
    print $usage;
}
if (@ARGV < 1) {
    print "too few args. Exiting.\n";
    exit;
}

my $i_arg=0;
my $data_source = $ARGV[$i_arg++];
if($qsubbed == 1) {
    my $output_file = "tmp/$data_source.$output_id.out";
# send standard out and stderr to $output_File
    use IO::Handle;
    *STDERR = *STDOUT;		# send standard error to standard out
    open OUTPUT, '>',"$output_file" or die $!;
    STDOUT->fdopen( \*OUTPUT, 'w' ) or die $!;
}

#my $hrs_to_subtract = abs($ARGV[$i_arg++]) || 0;

my $startSecs = $ARGV[$i_arg++];
my $endSecs = $ARGV[$i_arg++];

my $reprocess=0;
if(defined $ARGV[$i_arg++]) {
    $reprocess=1;
}

# look into the future up to 12 hours to get  forecasts valid in the future
my $time = time();
#my $time = time() + 12*3600 - $hrs_to_subtract*3600;
# put on 12 hour boundary
#$time -= $time%(12*3600);
#my @valid_times = ($time-24*3600, $time-12*3600, $time );

my $soundings_table = "${data_source}_raob_soundings";
# see if the needed tables exist
$dbh->do("use soundings");
$query = qq(show tables like "$soundings_table");
print "in soundings db: $query\n";
my $result = $dbh->selectrow_array($query);
print "result is $result\n";

unless($result) {
    # need to create the necessary tables
    $query = "create table $soundings_table like soundings.template";
    print "$query;\n";
    $dbh->do($query);
}
$dbh->do("use ruc_ua");
$query = qq(show tables like "$data_source");
print "in ruc_ua db: $query\n";
my $result = $dbh->selectrow_array($query);
print "result is $result\n";
unless($result) {
    # need to create the necessary tables
    $query = "create table $data_source like RRtemplate";
    print "$query;\n";
    $dbh->do($query);
    # find out necessary regions
    $query =<<"EOI"
select regions from ruc_ua.regions_per_model where 1=1
and model = "$data_source"
EOI
;
    my @result = $dbh->selectrow_array($query);
    my @regions = split(/,/,$result[0]);
    print "regions are @regions\n";
    $dbh->do("use ruc_ua_sums2");
    my $iso="";
    if($data_source =~ /iso/) {
	$iso="iso";
    }


    foreach my $region (@regions) {
#	$query = "create table ${data_source}_Areg$region like ${iso}RR1h_Areg0";
	$query = "create table ${data_source}_Areg$region like ${iso}Template_Areg0";
	print "$query;\n";
	$dbh->do($query);
    }
}
$dbh->do("use soundings");
$query =<<"EOI"
    replace into soundings.$soundings_table
(site,time,fcst_len,s,hydro)
    values(?,?,?,?,?)
EOI
    ;
my $sth_load = $dbh->prepare($query);


# DEBUG
#@valid_times = (1267617600);

my $skip_db_load = 0;

# get fcst_lens for this model
my $query =<<"EOQ";
    select fcst_lens from ruc_ua.fcst_lens_per_model
    where model = '$data_source'
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

# DEBUG
#@fcst_lens = (-99);

#foreach my $valid_time (@valid_times) {
for(my $valid_time=$startSecs;$valid_time<=$endSecs;$valid_time+=12*3600) {
    foreach my $fcst_len_for_db (@fcst_lens) {
	my $found_files = 0;
	my $special_type = "none";
	my $desired_fcst_len = $fcst_len_for_db;
	my $make_soundings=1;
	my $run_time;
	if($fcst_len_for_db == -99) {
	    $desired_fcst_len = 0;
	    $run_time = $valid_time;
	    $special_type = "analysis";
	} elsif($fcst_len_for_db < 0) {
	    $desired_fcst_len = 0;
	    $run_time = $valid_time -abs($fcst_len_for_db)*3600;
	    $special_type = "persistence";
	} else {
	    $run_time = $valid_time -$fcst_len_for_db*3600;
	    $special_type = "none";
	}
	my $run_date = sql_datetime($run_time);
	my $valid_date = sql_datetime($valid_time);
	#print "looking for $fcst_len_for_db h fcst valid at $valid_date, run at $run_date\n";
	if($reprocess == 0 &&
	   soundings_loaded($soundings_table,$valid_date,$fcst_len_for_db,$special_type,$dbh)) {
	    print "soundings already loaded for ${fcst_len_for_db}h fcst valid at $valid_date\n";
	    $make_soundings=0;
	} 
	my($run_year,$run_month_num,$run_mday,$run_hour,$run_fcst_len);
	
	# soundings are avaliable. see if we've already generated statistics
	if($reprocess == 0 &&
	   stats_generated($data_source,$valid_time,$fcst_len_for_db)) {
	    print "stats already generated\n";
	} else {
	    # stats not yet generated. See if raobs are avaliable
	    if(raobs_loaded($valid_time)) {
		# we can generate comparison stats
		my $command = "java -Xmx256m Verify3 dummy_dir $data_source ".
		#my $command = "java Verify3 dummy_dir $data_source ".
		    "$valid_time $valid_time $fcst_len_for_db";
		print "$command\n";
		if(system($command) != 0) {
		    print "problem with |$command|: $!";
		} else {
		    # save residuals between RAOB and model
		    #record_raob_resids($dbh,$data_source,$valid_time,$fcst_len_for_db);
		}
	    } else {
		print "RAOBs not (yet) available. NOT MAKING STATS\n";
	    }
	}
   } # end loop over fcst_lens
} # end loop over valid times

# now clean up
unlink $tmp_file ||
    print "could not unlink $tmp_file: $!";
unlink $ENV{model_sounding_file} ||
   die "cannot unlink $ENV{model_sounding_file}: $!";
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
    if(-M $file > .7) {
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
sub sql_date_hour {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return (sprintf("%4d-%2.2d-%2.2d",$year,$mon,$mday),$hour);
}

sub soundings_loaded($table,$valid_date,$fcst_len,$special_type,$dby) {
    my ($table,$valid_date,$fcst_len,$special_type,$dbh) = @_;
    if($special_type eq "analysis") {
	$fcst_len = -99;
    }
    my $query=<<"EOI";
	select count(*) from soundings.$table
	where 1=1
	and time = '$valid_date'
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
    # line below is for debugging (to force reprocessing of an hour).
    return $n;
}

sub stats_generated($data_source,$valid_time,$fcst_len_for_db) {
    my ($data_source,$valid_time,$fcst_len) = @_;
    my($valid_day,$valid_hour) = sql_date_hour($valid_time);
    $dbh->do("use ruc_ua_sums2");
    my $table = "";
    my $query = qq{
	show tables from ruc_ua_sums2
	where Tables_in_ruc_ua_sums2 regexp '^${data_source}_A?reg[[:digit:]]*\$'};
    #print "query is $query\n";
    my @result = $dbh->selectrow_array($query);
    #print "result is @result\n";
    if(@result) {
	$table = $result[0];
    }
    $query =<<"EOI"
select count(*) from $table
where 1=1
and mb10 = 50
and fcst_len = $fcst_len
and hour = $valid_hour
and date = '$valid_day'
EOI
;
# xue
    print "query is $query\n";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my($n);
    $sth->bind_columns(\$n);
    $sth->fetch();
    #print "n returned is $n\n";
    return $n;
}
   
sub raobs_loaded($valid_time) {
    my($valid_time) = @_;
    my($valid_day,$valid_hour) = sql_date_hour($valid_time);
    my $query =<<"EOI"
select count(*) from ruc_ua.RAOB
where 1=1
and press = 500
and hour = $valid_hour
and date = '$valid_day'
EOI
;
    #print "query is $query\n";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my($n);
    $sth->bind_columns(\$n);
    $sth->fetch();
    #print "n returned is $n\n";
    my $result=0;
    if($n > 400) {
	$result = $n;
    }
    return $result;
}
    
