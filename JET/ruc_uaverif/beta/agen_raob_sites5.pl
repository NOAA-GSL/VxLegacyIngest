#!/usr/bin/perl
# these commands (with the dollar signs) tell the 'qsub' routine how to
# run this routine on 'service' nodes. Since they all start with '#', they
# are ignored when we run this program directly from the command prompt for debugging.
# But for production, we're required to use 'qsub' to keep the load on the supercomputer
# front ends reasonable
#
#  Set the name of the job.
#$ -N ruc_uaverif5
#  Make sure that the .e and .o file arrive in the working directory
#$ -cwd
#  Set the account
#$ -A wrfruc
#  Ask for 1 cpus of type service
#$ -pe service 1
#  My code is re-runnable
#$ -r y
# send mail on abort
#$ -m a
#$ -M verif-amb.gsd@noaa.gov
#
#  The max walltime 
#$ -l h_rt=01:00:00
#
#$ -e tmp/
#$ -o /dev/null
#
use strict;
#
# set up to call locally (from the command prompt) of via '
my $thisDir = $ENV{SGE_O_WORKDIR};
my $qsubbed=1;
unless($thisDir) {
    # we've been called locally instead of qsubbed
    $qsubbed=0;
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}
my $output_id = $ENV{JOB_ID} || $$;

my $DEBUG=1;
use DBI;
$ENV{db_machine} = "wolphin.fsl.noaa.gov";

#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
$thisDir = $ENV{PWD};

#set database connection parameters
# the routine below contains username and password
# (Unfortunately, you won't be able to access the db outside of GSD)
require "./set_connection.pl";
$ENV{DBI_DSN} = "DBI:mysql:soundings:wolphin.fsl.noaa.gov";

$ENV{model_sounding_file} = "model_sounding.$$.tmp";

# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $sth;
my $query="";
my $gzipped_sounding="";
my $gzipped_hydro="";
my $sql_date;
use Compress::Zlib;

$|=1;  #force flush of buffers after each print
$ENV{'PATH'}="/bin";
# CLASSPATH is needed for when the java routine 'Verify' is called much later
#$ENV{CLASSPATH} =
#    '/home/amb-verif/javalibs/mysql-connector-java-5.1.6/mysql-connector-java-5.1.6-bin.jar:'.
#    ".";
# CLASSPATH NO LONGER NEEDED -- we put all the needed libraries in Verify.jar

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
my ($alat1,$elon1,$elonv,$alattan,$grib_nx,$grib_ny,$grib_nz,$grib_dx,
    $grib_type,$grid_type,$valid_date_from_file,$fcst_len_from_file);
my $tmp_file = "$$.data.tmp";

use lib "./";
require "timelocal.pl";   #includes 'timegm' for calculations in gmt
require "./get_model_file.pl";
require "./get_grid.pl";

#get best return address
my $returnAddress = "(Unknown-Requestor)";
if($ENV{REMOTE_HOST}) {
    $returnAddress = $ENV{REMOTE_HOST};
} else {
    # get the domain name if REMOTE_HOST is not set
    my $addr2 = pack('C4',split(/\./,$ENV{REMOTE_ADDR}));
    $returnAddress = gethostbyaddr($addr2,2) || $ENV{REMOTE_ADDR};
}
my $i_arg=0;
my $data_source = $ARGV[$i_arg++];
my $soundings_file = "${data_source}_raob_soundings";
if($qsubbed == 1) {
    my $output_file = "tmp/$data_source.$output_id.out";
# send standard out (and stderr, see above) to $output_File
    use IO::Handle;
    open OUTPUT, '>',"$output_file" or die $!;
    STDOUT->fdopen( \*OUTPUT, 'w' ) or die $!;
}
# Normally, if a valid hour/forecast-length combination has already been processed, it
# won't be reprocessed. But the caller can override this to force reprocessing
my $reprocess=0;
my $ini=0;
if(defined $ARGV[$i_arg] && $ARGV[$i_arg] > 0) {
    $reprocess=1;
}
$i_arg++;
my $hrs_to_subtract = abs($ARGV[$i_arg++]);

if(defined $ARGV[$i_arg] && $ARGV[$i_arg] eq "ini") {
    # process 'ini' files (ini)
    $ini=1;
}

$query =<<"EOI"
    replace into $soundings_file 
(site,time,fcst_len,s,hydro)
    values(?,?,?,?,?)
EOI
    ;
# set up this query to use later in the code
my $sth_load = $dbh->prepare($query);


# look into the future up to 12 hours to get  forecasts valid in the future
my $time = time() + 12*3600 - $hrs_to_subtract*3600;
# put on 12 hour boundary
$time -= $time%(12*3600);
my @valid_times = ( $time-12*3600, $time-24*3600,$time  );

# DEBUG
#@valid_times = (1267617600);

my $skip_db_load = 0;

my $station_file = "$$.new_raobs.txt";
# create raobs file
my $region = 0;			# HARDWIRED FOR RUC
my $cmd = "./create_raob_file.pl $station_file $region";
`$cmd`;

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
    # default fcst_lens for RUC (retro runs)
    $fcst_lens = "0,1,3,6,9,12";
}
if($ini == 1) {
    $fcst_lens = "-99,".$fcst_lens;
}
my @fcst_lens = split(",",$fcst_lens);

foreach my $valid_time (@valid_times) {
    foreach my $fcst_len_for_db (@fcst_lens) {
	my $found_files = 0;
	my $special_type = "none";
	my $desired_fcst_len = $fcst_len_for_db;
	if($fcst_len_for_db == -99) {
	    $desired_fcst_len = 0;
	    $special_type = "ini";
	}
	my $run_time = $valid_time -$desired_fcst_len * 3600;
	my $run_date = sql_datetime($run_time);
	my $valid_date = sql_datetime($valid_time);
	print "looking for $fcst_len_for_db h fcst valid at $valid_date, run at $run_date\n";
	# get_model_file knows where on disk the model output for each $data_source is stored.
	($desired_filename,$out_file,$fcst_len) =
	    &get_model_file($run_time,$data_source,$DEBUG,$desired_fcst_len,
			 $special_type);
	if($DEBUG) {
	    #print "got file |$desired_filename|\n";
	}
	if($desired_filename) {
	    if($reprocess == 0 &&
	       already_loaded($data_source,$valid_date,$fcst_len_for_db,$special_type,$dbh)) {
		print "ALREADY LOADED: $desired_filename\n";
		next;
	    }
	    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) =
		gmtime($run_time);
	    $yday++;			# make it 1-based
	    my $atime = sprintf("%02d%03d%02d",$year%100,$yday,$hour);
	    my $recipients="willian.r.moninger\@noaa.gov,Ming.Hu\@noaa.gov,Stephen.Weygandt\@noaa.gov";
	    $recipients="william.r.moninger\@noaa.gov";
	    # send mail when files are missing (currently turned off with the if(0) )
	    if(0) {
	    open MAIL,"|/usr/sbin/sendmail -t";
	    print MAIL<<EOI
To: $recipients
From: RUC_verification.processing
Reply-to: Bill.Moninger\@noaa.gov
Subject: Found $data_source $fcst_len_for_db h fcst valid $valid_date

Found $data_source $fcst_len_for_db h fcst valid $valid_date
$desired_filename
EOI
;
	    print "MAIL $data_source $desired_filename was FOUND\n";

	    close MAIL;
	}
	my($run_year,$run_month_num,$run_mday,$run_hour,$run_fcst_len);

	# 'col_wgrib.x' is a version of wgrib, which reads grib (version 1) files.
	# this call simply gets grid information from the file.
	# I can send you a typical output if you want to try to parse it in python.
	    $found_files++;
	    my $arg_unsafe =
		"${thisDir}/col_wgrib.x -V $desired_filename";
	    $arg_unsafe =~ /([a-zA-Z0-9\.\/\~\_\-\, ]*)/;
	    my $arg = $1;
	    if($DEBUG) {
		#print "arg is $arg\n";
	    }
	    unless(open(V,"$arg 2>&1 |")) {
		print "couldnt verify grib file: $!";
		$BAD=1;
	    }
	    ($alat1,$elon1,$elonv,$alattan,$grib_nx,$grib_ny,$grib_dx,
	       $grib_type,$grid_type,$valid_date_from_file,$fcst_len_from_file) =
		   get_grid($desired_filename,$thisDir,$DEBUG);
	    # put dx in km
	    $grib_dx /= 1000;
	    
		if(1) {
		    print "|$alat1| |$elon1| |$elonv| |$alattan| ".
			"|$grib_nx| |$grib_ny| |$grib_dx|\n";
		}
		if($valid_date_from_file != $valid_date) {
		    print "BAD VALID DATE from file: $valid_date_from_file\n";
		    exit(1);
		}
		
		my($vsec,$vmin,$vhour,$vmday,$vmonth,$vyear) =
		    gmtime($valid_time);
		$vyear += 1900;
		my (@month)= qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
		my $month_name = $month[$vmonth];
		my $time_line=sprintf("%-11.11s %2.2d     %2.2d      $month_name     $vyear\n",
				      $data_source,$vhour,$vmday);
		print "soundings for: $time_line";

		# this calls one of two C programs to read the grib file and generate soundings
		# for all the sites in $station_file. The first program generates soundings
		# from files with 'native' levels (hybrid-sigma levels for the RUC)
		# the second generates soundings from files with pressure levels (isobaric) files.
	        # we like to compare soundings and verification results for each kind of output file,
		# even they are both produced from the same model.
	    $grib_nz = 50; # hybrid levels for the RUC
		$arg_unsafe = "$thisDir/agrib_soundings.x ".
		    "$data_source $desired_filename $station_file ".
		    "$alat1 $elon1 $elonv $alattan $grib_dx $grib_nx $grib_ny $grib_nz";
		if($data_source =~ /iso/) {
		    $grib_nz = 37; # a hack for RUC isobaric
		    if($grib_type == 1) {
			$arg_unsafe = "$thisDir/iso_agrib_soundings.x ".
			    "$data_source $desired_filename $station_file ".
			    "$alat1 $elon1 $elonv $alattan $grib_dx $grib_nx $grib_ny";
		    } else {
			$arg_unsafe = "$thisDir/iso_agrib2_soundings.x ".
			    "$data_source $desired_filename $tmp_file $station_file ".
			    "$grib_type $alat1 $elon1 $elonv $alattan ".
			    "$grib_dx $grib_nx $grib_ny $grib_nz";
		    }
		}
		$arg_unsafe =~ /([a-zA-Z0-9\.\/\~\_\-\, ]*)/;
		my $arg = $1;
		if($DEBUG) {
		    print "arg is $arg\n";
		}
		# we now read data from 'PULL', which is the output from the executables described
		# above
		open (PULL,"/usr/bin/time $arg 2>&1 |");
		$data ="";
		$name="";
		$all_levels_filled = 0;
		while(<PULL>) {
		    #print;
		    if(/SUCCESS/) {
			$all_levels_filled = 1;
			print "Yea. all levels filled!\n";
		    }
		    if($all_levels_filled) {
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
			    if($special_type eq "ini") {
				$title .=" dfi output valid for ";
			    } else {
				$title .=" analysis valid for ";
			    }
			} else {
			    $title .=" $fcst_len2 h forecast valid for ";
			}
			$title .= $differ;
			# NEW WAY TO STORE SOUNDINGS USING THE DATABASE
			my $un_gzipped = "$title\n$data";
			$gzipped_sounding = Compress::Zlib::memGzip($un_gzipped) ||
			    die "cannot do memGzip for sounding data: $!\n";
			$sql_date = sql_datetime($valid_time);
		    } elsif (/Begin hydrometeor data for (\w*)/) {
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
			print "$name ($hydro_length) ";
			# the output from the C program is ASCII soundings for each of the
			# requested sites. The soundings contain 'regular' sounding data
			# (pressure, height, temperature, dewpoint, and wind)
			# and also hydrometeor data.
			# since few soundings have hydrometeor data, I treat those separately.
			# We gzip them to save space, and store them in the database using
			# the command below.
			$sth_load->execute($name,$sql_date,$fcst_len_for_db,
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
		} # end while(<PULL>)
		close PULL;
	    print "\n";
		unless($all_levels_filled) {
		    print STDERR "FAILURE: all levels not filled.\n";
		}
		    
	    if($all_levels_filled && $skip_db_load == 0) {
		# now store interpolated files in the database.
		# Verify is a java program that takes the soundings and sets them up to be
		# compared level by level with RAOB soundings. We generate verification statistics
		# from this comparison.
		# I'll put more comments in the Verify code that I'll send you.
		my $command = "/opt/java/jdk1.6.0_04/bin/java -jar Verify.jar dummy_dir $data_source ".
		    "$valid_time $valid_time $fcst_len_for_db";
		print "$command\n";
		system($command) &&
		    print "problem with |$command|: $!";
	    } else {
		print "NOT LOADING DB\n\n";
	    }
	}# end if($desired_filename) # UNCOMMENT THIS TO END SPECIAL TEST
    } # end loop over fcst_lens
} # end loop over valid times

# now clean up
unlink $station_file ||
    print "could not unlink $station_file: $!";
unlink $ENV{model_sounding_file} ||
   die "cannot unlink $ENV{model_sounding_file}: $!";
# clean up tmp directory
# When we qsub a job instead of execute it from the command line, there's no standard output
# so we put the output into the tmp directory, and leave it around for 0.7 days in case we need
# to look at it, for debugging.
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
unlink $tmp_file ||
    die "could not unlink $tmp_file: $!";
print "NORMAL TERMINATION\n";


# generates a datetime in SQL format
sub sql_datetime {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
		   $year,$mon,$mday,$hour,$min,$sec);
}

# checks to see whether this model,valid date, and forecast length has
# already been processed.
sub already_loaded($model,$valid_date,$fcst_len,$special_type,$dby) {
    my ($model,$valid_date,$fcst_len,$special_type,$dbh) = @_;
    if($special_type eq "ini") {
	$fcst_len = -99;
    }
    my $query=<<"EOI";
	select count(*) from $soundings_file
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
    return $n;
}

