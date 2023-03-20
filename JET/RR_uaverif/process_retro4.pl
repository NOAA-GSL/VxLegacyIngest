#!/usr/bin/perl
#
#SBATCH -J RAOB_retro_verif
#SBATCH --mail-user=verif-amb.gsl@noaa.gov
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p sjet,vjet,xjet
#SBATCH -t 01:00:00
#SBATCH --mem=16G
#SBATCH -D .
#SBATCH -e /home/amb-verif/RR_uaverif/beta/tmp/RAOB_retro_verif.o%j
#SBATCH -o /home/amb-verif/RR_uaverif/beta/tmp/RAOB_retro_verif.e%j
#

use strict;
use POSIX;
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
my $data_source = $ARGV[0];
my $startSecs = $ARGV[1];
if($startSecs%(12*3600) != 0) {
    print "start time must be at a RAOB time (0Z or 12Z)\n";
    exit(1);
}
my $endSecs = $ARGV[2];
my $dp_to_rh_calculator = $ARGV[3];
unless($dp_to_rh_calculator) {
    die "usage: process_retro4.pl model_name start_secs end_secs dp_to_rh_calculator\n";
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

my $hydro = 1; #always process hydrometers here
my $soundings_table = "soundings.${data_source}_raob_soundings";
my $sums_table0;

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

# see if needed tables exist
$dbh->do("use ruc_ua");
$query = qq(show tables like "$data_source");
my $result = $dbh->selectrow_array($query);
$dbh->do("use ruc_ua_sums2");

my @regions;

if($data_source =~ /^RAP/) {
   $sums_table0 = "ruc_ua_sums2.${data_source}_Areg6";
   @regions = (2,1,0,6,14,13,17,18,19);
} elsif($data_source =~ /^RRFS_NA_13km/) {
   $sums_table0 = "ruc_ua_sums2.${data_source}_Areg6";
   @regions = (2,1,0,6,14,13,17,18,19);
} elsif($data_source =~ /AK/) {
    print "SETTING ALASKA REGION\n\n";
   $sums_table0 = "ruc_ua_sums2.${data_source}_Areg13";
   @regions = (13);
} elsif($data_source =~ /^RRFS/) {
   $sums_table0 = "ruc_ua_sums2.${data_source}_Areg14";
   @regions = (5,2,1,14,15,16,17,18,13,19);
} elsif($data_source =~ /^RR/) {
   $sums_table0 = "ruc_ua_sums2.${data_source}_Areg6";
   @regions = (2,1,0,6,14,13,17,18,19);
} elsif($data_source =~ /^HRRR/) {
   $sums_table0 = "ruc_ua_sums2.${data_source}_Areg14";
   @regions = (5,2,1,14,15,16,17,18,13,19);
} elsif($data_source =~ /^RTMA/) {
   $sums_table0 = "ruc_ua_sums2.${data_source}_Areg14";
   @regions = (5,2,1,14,15,16,17,18,13,19);
} else {
   $sums_table0 = "ruc_ua_sums2.${data_source}_Areg0";
   @regions = (5,2,1,14,15,16,17,18,13,19,0,6,8,9,10,11,7);
}

unless($result) {
    # need to create the necessary tables
    $query = "create table if not exists $soundings_table like soundings.template";
    $dbh->do($query);
    $query = "create table if not exists $sums_table0 like ruc_ua_sums2.RAP_Areg0";
    $dbh->do($query);
    foreach my $reg (@regions) {
       $query = "create table if not exists ruc_ua_sums2.${data_source}_Areg${reg} like ruc_ua_sums2.RAP_Areg0";
       $dbh->do($query);
    }
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
    # make sure the same rh calculator was asked for
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
my($alat1,$elon1,$elonv,$alattan,$grib_nx,$grib_ny,$grib_nz,$grib_dx,
   $grib_type,$grid_type,$valid_date_from_file,$fcst_len_from_file,$wind_rot_flag);
my $tmp_file = "tmp/$$.data.tmp";

use lib "./";
use Time::Local;
#require "timelocal.pl";   #includes 'timegm' for calculations in gmt
require "./get_retro_RR_file.pl";
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
if($qsubbed == 1) {
    my $output_file = "tmp/$data_source.$output_id.out";
# send standard out and stderr to $output_File
    use IO::Handle;
    *STDERR = *STDOUT;		# send standard error to standard out
    open OUTPUT, '>',"$output_file" or die $!;
    STDOUT->fdopen( \*OUTPUT, 'w' ) or die $!;
}

my $skip_db_load = 0;

my $station_file = "$$.new_RR_raobs.txt";
# create raobs file
my $region = 6;			# HARDWIRED FOR RR
my $cmd = "./create_raob_file.pl $station_file $region";
print "cmd $cmd\n";
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
    $fcst_lens = "-99,0,1,3,6,9,12,18,21,24,27,30,33,36,39";
}
my @fcst_lens = split(",",$fcst_lens);
print "fcst_lens are @fcst_lens\n";

# DEBUG
#@fcst_lens = (-99);
for(my $valid_time=$startSecs;$valid_time<=$endSecs;$valid_time+=12*3600) {
    foreach my $fcst_len_for_db (@fcst_lens) {
        my $found_files = 0;
        my $special_type = "none";
        my $desired_fcst_len = $fcst_len_for_db;
        my $make_soundings=1;
        if($fcst_len_for_db == -99) {
            $desired_fcst_len = 0;
            $special_type = "analysis";
        }
        my $run_time = $valid_time -$desired_fcst_len * 3600;
        my $run_date = sql_datetime($run_time);
        my $valid_date = sql_datetime($valid_time);
        print "looking for $fcst_len_for_db h fcst valid at $valid_date, run at $run_date\n";
        ($desired_filename,$out_file,$fcst_len) =
            &get_retro_RR_file($run_time,$data_source,$DEBUG,$desired_fcst_len,
                         $special_type);
        if($DEBUG) {
	    print "desired_filename: |$desired_filename| (reprocess = $reprocess)\n";
        }
        if($desired_filename) {
            if($reprocess == 0 &&
               already_loaded($data_source,$valid_time,$fcst_len_for_db,$special_type,$dbh,$sums_table0)) {
                print "ALREADY LOADED: $desired_filename\n";
                next;
            }
            my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) =
                gmtime($run_time);
            $yday++;
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
	
	if($desired_filename && $make_soundings) {
	    $found_files++;
	    ($alat1,$elon1,$elonv,$alattan,$grib_nx,$grib_ny,$grib_dx,
	     $grib_type,$grid_type,$valid_date_from_file,$fcst_len_from_file,$wind_rot_flag) =
		 get_grid($desired_filename,$thisDir,$DEBUG);
	    # put dx in km
	    $grib_dx /= 1000;
	    $grib_nz = 50;	# see setting of grib_nz later.
	    
	    if(1) {
		print "|$alat1| |$elon1| |$elonv| |$alattan| ".
		    "|$grib_nx| |$grib_ny| |$grib_dx|\n";
	    }
	    if($valid_date_from_file != $valid_date) {
		print "BAD VALID DATE from file: $valid_date_from_file\n";
		exit(1);
	    }
	    my $hydro=0;	# 
	    if($data_source =~ /^isoRR1h/) {
		$grib_nz = 39;
		$hydro = 1;
            }elsif($data_source =~ /^HRRR_iso/) {
		$grib_nz = 39;
		$hydro = 1;  # check if cloud, ice variable in grib file 
	    } elsif($data_source =~ /^isoRRrapx/) {
		$grib_nz = 37;
		$hydro = 0;
	    } 
	    elsif($data_source eq "RAP_OPS_iso_242") {
		$grib_nz = 37;
		$hydro = 1;
	    }
	    elsif($data_source eq "RAP_NCOpara_iso_242") {
		$grib_nz = 37;
		$hydro = 1;
	    }
            elsif($data_source =~ /iso/ && $data_source =~ /^RRFS/) {
                $grib_nz = 45;
                $hydro = 0;
            }
            elsif($data_source =~ /^RRFS/) {
                $grib_nz = 65;
                $hydro = 0;
            }
	    if($grib_nz < 37) {
		print "BAD NUMBER OF LEVELS: < 37.\n";
		exit(1);
	    }
	    elsif($data_source =~ /iso/) {
                $grib_nz = 39; 
                $hydro = 1;
            }   
	    if(1) {
		print "|$alat1| |$elon1| |$elonv| |$alattan| ".
		    "|$grib_nx| |$grib_ny| |$grib_dx| nz = |$grib_nz|\n";
	    }
		
		my($vsec,$vmin,$vhour,$vmday,$vmonth,$vyear) =
		    gmtime($valid_time);
		$vyear += 1900;
		my (@month)= qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
		my $month_name = $month[$vmonth];
		my $time_line=sprintf("%-11.11s %2.2d     %2.2d      $month_name     $vyear\n",
				      $data_source,$vhour,$vmday);
		print "soundings for: $time_line";

	    my $arg_unsafe;
#	    $arg_unsafe = "$thisDir/wrgsi_soundings.x ".
#		"$data_source $desired_filename $grib_type $grid_type $tmp_file $station_file ".
#		"$alat1 $elon1 $elonv $alattan $grib_dx $grib_nx $grib_ny $grib_nz";

            $arg_unsafe = "$thisDir/new_wrgsi_soundings.x ".
                "$data_source $desired_filename $grib_type $grid_type $tmp_file $station_file ".
                "$alat1 $elon1 $elonv $alattan $grib_dx $grib_nx $grib_ny $grib_nz $hydro $wind_rot_flag";
	    if($data_source =~ /iso/) {
		$arg_unsafe = "$thisDir/iso_wrgsi_soundings.x ".
		    "$data_source $desired_filename $grib_type $grid_type $tmp_file $station_file ".
		    "$alat1 $elon1 $elonv $alattan $grib_dx $grib_nx $grib_ny $grib_nz $hydro $wind_rot_flag";
#	    } elsif(!defined $alat1) {
#		$arg_unsafe = "$thisDir/rotLL_soundings.x ".
#		    "$data_source $desired_filename $grib_type $tmp_file $station_file";
#	    }


	    } 
            if($grid_type == 20 || $grid_type==21 || $grid_type==22 || $grid_type==23) {
		$arg_unsafe = "$thisDir/rotLL_soundings.x ".
		    "$data_source $desired_filename $grib_type $grid_type $tmp_file $station_file $hydro";
                if($data_source =~ /iso/) {
                    $arg_unsafe = "$thisDir/rotLL_soundings_iso.x ".
                        "$data_source $desired_filename $grib_type $grid_type $tmp_file $station_file $hydro";
                 }
            }



	    $arg_unsafe =~ /([a-zA-Z0-9\.\/\~\_\-\, ]*)/;
	    my $arg = $1;
	    if($DEBUG) {
		print "arg is $arg\n";
	    }
	    open (PULL,"/usr/bin/time $arg 2>&1 |") || 
		print " error is $!";
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
			    if($special_type eq "analysis") {
				$title .=" analysis valid for ";
			    } elsif($special_type eq "persistence") {
				$title .= sprintf(" persistence %d h forcast valid for ",abs($fcst_len_for_db));
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
		}# end while(<PULL>)
		close PULL;
		print "\n";
		unless($all_levels_filled) {
		    print STDERR "FAILURE: all levels not filled.\n";
		}
	}  # end if($desired_filename && $make_soundings)

	if($make_soundings && ($found_sounding_data == 0 )) {
	    print "FAILED TO MAKE NEEDED SOUNDINGS!\n";
	    next;
	}
	# soundings are avaliable. see if we've already generated statistics
	if($reprocess == 0 &&
	   stats_generated($data_source,$valid_time,$fcst_len_for_db)) {
	    print "stats already generated\n";
	} else {
	    # stats not yet generated. See if raobs are avaliable
	    if($desired_filename && raobs_loaded($valid_time)) {
		# we can generate comparison stats
		my $command = "~/java8/java Verify3 dummy_dir $data_source ".
		    "$valid_time $valid_time $fcst_len_for_db";
		print "$command\n";
		if(system($command) != 0) {
		    print "problem with |$command|: $!";
		} else {
		    # save residuals between RAOB and model
		    #record_raob_resids($dbh,$data_source,$valid_time,$fcst_len_for_db);
		}
	    } else {
		print "NOT LOADING DB. NOT MAKING STATS\n";
	    }
	}
   } # end loop over fcst_lens
} # end loop over valid times

# now clean up
unlink $tmp_file ||
    print "could not unlink $tmp_file: $!";
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
    #print "query is $query\n";
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
    if($n > 300) {		# lower the min number of RAOBs. For 12z we're getting too few as of April 2020
	$result = $n;
    }
    return $result;
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
sub sql_date {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d",
                   $year,$mon,$mday);
}                                        
