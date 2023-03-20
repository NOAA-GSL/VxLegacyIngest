#!/usr/bin/perl
#
#  Set the name of the job.
#$ -N RR_retro
#  Make sure that the .e and .o file arrive in the working directory
#$ -cwd
#  Set the account
#$ -A nrtrr
#  Ask for 1 cpus of type service
#$ -pe service 1
#  My code is re-runnable
#$ -r y
# send mail on abort
#$ -m a
#$ -M Haidao.Lin@noaa.gov
#
#  The max walltime 
#$ -l h_rt=01:00:00
#
#$ -e tmp/
#$ -o /dev/null
#

use strict;
use POSIX;
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
my $data_source = $ARGV[0];
my $startSecs = $ARGV[1];
if($startSecs%(12*3600) != 0) {
    print "start time must be at a RAOB time (0Z or 12Z)\n";
    exit(1);
}
my $endSecs = $ARGV[2];
my $dp_to_rh_calculator = $ARGV[3];
unless($dp_to_rh_calculator) {
    die "usage: process_retro3.pl model_name start_secs end_secs dp_to_rh_calculator\n";
} else {
    # make sure it matches
    unless($dp_to_rh_calculator eq "GFS-fixer-Wobus" ||
	   $dp_to_rh_calculator eq "Bolton" ||
	   $dp_to_rh_calculator eq "FW-to-Wobus" ||
	   $dp_to_rh_calculator eq "Wobus" ||
	   $dp_to_rh_calculator eq "Fan-Whiting") {
	die "incorrect RH calculator. Calculator '$dp_to_rh_calculator' not recognized\n";
    }
}
my $reprocess=0;
if(defined $ARGV[4] && $ARGV[4] > 0) {
    $reprocess=1;
}


my $hydro = 1;# always process hydrometeors here
my $soundings_table = "soundings.${data_source}_raob_soundings";
my $sums_table0 = "ruc_ua_sums2.${data_source}_Areg0";

#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
$thisDir = $ENV{PWD};

#set database connection parameters
$ENV{DBI_USER} = "UA_retro";
$ENV{DBI_PASS} = "HaidaoEric";
$ENV{DBI_DSN} = "DBI:mysql:soundings:wolphin.fsl.noaa.gov";

$ENV{model_sounding_file} = "model_sounding.$$.tmp";

# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $sth;
my $query="";

# see if the needed tables exist
$dbh->do("use ruc_ua");
$query = qq(show tables like "$data_source");
my $result = $dbh->selectrow_array($query);
$dbh->do("use ruc_ua_sums2");

unless($result) {
    # need to create the necessary tables
    $query = "create table if not exists $soundings_table like soundings.template";
    $dbh->do($query);
    $query = "create table if not exists $sums_table0 like ruc_ua_sums2.RAP_Areg0";
    $dbh->do($query);
    $query = "create table if not exists ruc_ua_sums2.${data_source}_Areg1 like ruc_ua_sums2.RAP_Areg0";
    $dbh->do($query);
    $query = "create table if not exists ruc_ua_sums2.${data_source}_Areg2 like ruc_ua_sums2.RAP_Areg0";
    $dbh->do($query);
    $query = "create table if not exists ruc_ua_sums2.${data_source}_Areg5 like ruc_ua_sums2.RAP_Areg0";
    $dbh->do($query);
    $query = "create table if not exists ruc_ua_sums2.${data_source}_Areg6 like ruc_ua_sums2.RAP_Areg0";
    $dbh->do($query);
    $query = "create table if not exists ruc_ua_sums2.${data_source}_Areg13 like ruc_ua_sums2.RAP_Areg0";
    $dbh->do($query);
   $query = "create table if not exists ruc_ua_sums2.${data_source}_Areg17 like ruc_ua_sums2.RAP_Areg0";
    $dbh->do($query);
   $query = "create table if not exists ruc_ua_sums2.${data_source}_Areg18 like ruc_ua_sums2.RAP_Areg0";
    $dbh->do($query);
    my $today = POSIX::strftime("%d-%b-%Y",gmtime(time())); 
    $query = qq{replace into ruc_ua.dp_to_rh_calculator_per_model VALUES}.
	qq{('$data_source','$dp_to_rh_calculator','added $today')};
    unless($dbh->do($query)) {
	print "error with query $query\n";
	exit(1);
    }
    $query = "create table ruc_ua.$data_source like  ruc_ua.RRtemplate";
    $dbh->do($query);
    print "created needed tables\n";
} else {
    # make sure the same rh_calculator was asked for
    $query = qq{select calculator from ruc_ua.dp_to_rh_calculator_per_model where model = '$data_source'};
    print "$query\n";
    $sth = $dbh->prepare($query);
    $sth->execute();
    my $result = $sth->fetchrow_hashref();
    my $old_calculator = $result->{calculator};
    if(defined $old_calculator &&
       $old_calculator ne $dp_to_rh_calculator) {
	die "rh calculators don't match. previous: $old_calculator, this job: $dp_to_rh_calculator\n";
    }
}

$query =<<"EOI"
    replace into $soundings_table 
(site,time,fcst_len,s,hydro)
    values(?,?,?,?,?)
EOI
    ;
my $sth_load = $dbh->prepare($query);
my $gzipped_sounding="";
my $gzipped_hydro="";
my $sql_date;
use Compress::Zlib;

$|=1;  #force flush of buffers after each print
#$ENV{'PATH'}="/bin:/usr/bin";
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
my ($desired_filename,$out_file,$fcst_len,$elev,$name,$id,$data,$bad_data);
my ($good_data,$found_sounding_data,$maps_coords,$title,$logFile);
my ($dist,$dir,$differ);
my ($loaded_soundings);
my $BAD=0;
my $all_levels_filled = 0;

my $grid_type = 0;             # unknown                                                                                                                                  
my $grib_type = 0;
my($alat1,$elon1,$elonv,$alattan,$grib_nx,$grib_ny,$grib_nz,$grib_dx,
   $grib_type,$grid_type,$valid_date_from_file,$fcst_len_from_file);

use lib "./";
require "timelocal.pl";   #includes 'timegm' for calculations in gmt
require "./get_RR_file.pl";
require "./jy2mdy.pl";
require "./get_grid_smallrap.pl";

#get best return address
my $returnAddress = "(Unknown-Requestor)";
if($ENV{REMOTE_HOST}) {
    $returnAddress = $ENV{REMOTE_HOST};
} else {
    # get the domain name if REMOTE_HOST is not set
    my $addr2 = pack('C4',split(/\./,$ENV{REMOTE_ADDR}));
    $returnAddress = gethostbyaddr($addr2,2) || $ENV{REMOTE_ADDR};
}
if($qsubbed == 1) {
    my $output_file = "tmp/$data_source.$output_id.out";
# send standard out (and stderr, see above) to $output_File
    use IO::Handle;
    open OUTPUT, '>',"$output_file" or die $!;
    STDOUT->fdopen( \*OUTPUT, 'w' ) or die $!;
}

my $skip_db_load = 0;

my $station_file = "$$.new_RR_raobs.txt";
# create raobs file
my $region = 6;			# HARDWIRED FOR RR
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
    # default fcst_lens for RR (retro runs)
    $fcst_lens = "-99,0,1,3,6,9,12,18";
    # DEBUGGING
    #$fcst_lens="6";
}
my @fcst_lens = split(",",$fcst_lens);

for(my $valid_time=$startSecs;$valid_time<=$endSecs;$valid_time+=12*3600) {
    foreach my $fcst_len_for_db (@fcst_lens) {
	my $found_files = 0;
	my $special_type = "none";
	my $desired_fcst_len = $fcst_len_for_db;
	if($fcst_len_for_db == -99) {
	    $desired_fcst_len = 0;
	    $special_type = "analysis";
	}
	my $run_time = $valid_time -$desired_fcst_len * 3600;
	my $run_date = sql_datetime($run_time);
	my $valid_date = sql_datetime($valid_time);
	print "looking for $fcst_len_for_db h fcst valid at $valid_date, run at $run_date\n";
	($desired_filename,$out_file,$fcst_len) =
	    &get_RR_file($run_time,$data_source,$DEBUG,$desired_fcst_len,
			 $special_type);
	if($DEBUG) {
	    #print "got file |$desired_filename|\n";
	}
	if($desired_filename) {
	    if($reprocess == 0 &&
	       already_loaded($data_source,$valid_time,$fcst_len_for_db,$special_type,$dbh,$sums_table0)) {
		print "ALREADY LOADED: $desired_filename\n";
		next;
	    }
	    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) =
		gmtime($run_time);
	    $yday++;			# make it 1-based
	    my $atime = sprintf("%02d%03d%02d",$year%100,$yday,$hour);
	    my $recipients="willian.r.moninger\@noaa.gov,Ming.Hu\@noaa.gov,Stephen.Weygandt\@noaa.gov";
	    $recipients="william.r.moninger\@noaa.gov";
	    if(0) {
	    open MAIL,"|/usr/sbin/sendmail -t";
	    print MAIL<<EOI
To: $recipients
From: RR_retro.processing
Reply-to: Bill.Moninger\@noaa.gov
Subject: Found $data_source $fcst_len_for_db h fcst valid $valid_date

Found $data_source $fcst_len_for_db h fcst valid $valid_date
$desired_filename
EOI
;
	    print "MAIL $data_source $desired_filename was FOUND\n";

	    close MAIL;
	}
	}

	my($run_year,$run_month_num,$run_mday,$run_hour,$run_fcst_len);
	
	if($desired_filename) {
	    $found_files++;

             ($alat1,$elon1,$elonv,$alattan,$grib_nx,$grib_ny,$grib_dx,
             $grib_type,$grid_type,$valid_date_from_file,$fcst_len_from_file) =
              get_grid($desired_filename,$thisDir,$DEBUG);
            # put dx in km                                                                                                         \
                                                                                                                                    
             $grib_dx /= 1000;
             $grib_nz = 50;      # 


	    unless($BAD) {
		
		if(1) {
		    print "|$alat1| |$elon1| |$elonv| |$alattan| ".
			"|$grib_nx| |$grib_ny| |$grib_dx| nz = |$grib_nz|\n";
		    print ("run times from file: $run_year,$run_month_num,$run_mday,".
			   "$run_hour,$run_fcst_len\n");
		}
		if($grib_nz == 0 && $data_source eq "isoRR1h") {
		    $grib_nz = 39;
		}
		if($grib_nz < 39) {
		    print "BAD NUMBER OF LEVELS: < 39.\n";
		    exit(1);
		}
#		my $valid_time_from_file = timegm(0,0,$run_hour,$run_mday,
#						  $run_month_num - 1,
#						  $run_year) + 3600*$run_fcst_len;
#		if($valid_time_from_file != $valid_time) {
#		    print "BAD VALID TIME from file: $valid_time_from_file\n";
#		    exit(1);
#		}
		

	

                 my($vsec,$vmin,$vhour,$vmday,$vmonth,$vyear) =gmtime($valid_time);

		$vyear += 1900;
		my (@month)= qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
		my $month_name = $month[$vmonth];
                my $time_line=sprintf("%-11.11s %2.2d     %2.2d      $month_name     $vyear\n",
                                      $data_source,$vhour,$vmday);
		print "soundings for: $time_line";



		my $arg_unsafe;

		my $tmp_file = "tmp/$$.retro-data.tmp";
		$arg_unsafe = "$thisDir/wrgsi_soundings.x ".
		    "$data_source $desired_filename $grib_type $tmp_file $station_file ".
		    "$alat1 $elon1 $elonv $alattan $grib_dx $grib_nx $grib_ny $grib_nz $hydro";
		if($data_source =~ /iso/) {
		    $arg_unsafe = "$thisDir/iso_wrgsi_soundings.x ".
			"$data_source $desired_filename $grib_type $tmp_file $station_file ".
			"$alat1 $elon1 $elonv $alattan $grib_dx $grib_nx $grib_ny $grib_nz";
		} elsif($grid_type == 20 || $grid_type==21) {
# xue change on 20140416
#		    $arg_unsafe = "$thisDir/rotLL_soundings.x ".
#			"$data_source $desired_filename $station_file";

		    $arg_unsafe = "$thisDir/rotLL_soundings.x ".
			"$data_source $desired_filename $grib_type $grid_type $tmp_file $station_file";
		}		    
		$arg_unsafe =~ /([a-zA-Z0-9\.\/\~\_\-\, ]*)/;
		my $arg = $1;
		if($DEBUG) {
		    print "arg is $arg\n";
		}
		open (PULL,"/usr/bin/time $arg 2>&1 |");
		$data ="";
		$name="";
		$all_levels_filled = 0;
		while(<PULL>) {
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
			    if($special_type eq "analysis") {
				$title .=" analysis valid for ";
			    } else {
				$title .=" dfi output valid for ";
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
		    } elsif(/groupel for/) {
			print;
		    } elsif ($good_data) {
			$data .= $_;
		    }
		    #if($DEBUG) {print;}
		}
		} # end while(<PULL>)
		close PULL;
		unless($all_levels_filled) {
		    print STDERR "FAILURE: all levels not filled.\n";
		}
	    }
	    if($all_levels_filled && $skip_db_load == 0) {
		# now store interpolated files in the database.
		my $command = "java Verify3 dummy_dir $data_source ".
		    "$valid_time $valid_time $fcst_len_for_db";
		print "$command\n";
		system($command) &&
		    print "problem with |$command|: $!";
	    } else {
		print "NOT LOADING DB\n\n";
	    }
	} # end if($desired_filename) # UNCOMMENT THIS TO END SPECIAL TEST
    } # end loop over fcst_lens
} # end loop over valid times

# now clean up
unlink $station_file ||
    print "could not unlink $station_file: $!";
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

sub sql_date {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d",
		   $year,$mon,$mday);
}
    
sub already_loaded($model,$valid_time,$fcst_len,$special_type,$dbh,$sums_table0) {
    my ($model,$valid_time,$fcst_len,$special_type,$dbh,$sums_table0) = @_;
    if($special_type eq "analysis") {
	$fcst_len = -99;
    }
    my $valid_day = sql_date($valid_time);
    my $valid_hours_1970 = int($valid_time/3600);
    my $valid_hour = $valid_hours_1970 % 24;
    my $query=<<"EOI";
	select count(*) from $sums_table0
	where 1=1
	and date = '$valid_day'
	and hour = $valid_hour
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
    #$n=0;
    return $n;
}

