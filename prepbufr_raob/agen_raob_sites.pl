#!/usr/bin/perl
#
####SBATCH -J pb_RAOB_verif  # jobnamr is set by ~/sb2.tcsh
#SBATCH --mail-user=verif-amb.gsl@noaa.gov
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service
#SBATCH -t 01:50:00
#SBATCH -D .
#SBATCH --mem=16G
#SBATCH -o tmp/%x.%j.job
#

use strict;
my $thisDir = $ENV{SLURM_SUBMIT_DIR};
my $qsubbed=1;
unless($thisDir) {
    # we've been called locally instead of qsubbed
    $qsubbed=0;
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}
my $output_id = $ENV{SLURM_JOB_ID} || $$;

my $DEBUG=1;
use DBI;


#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
$thisDir = $ENV{PWD};


#set database connection parameters
require "./set_connection.pl";
$ENV{DBI_DSN} = "DBI:mysql:soundings_pb:wolphin.fsl.noaa.gov";
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
   $grib_type,$grid_type,$valid_date_from_file,$fcst_len_from_file,$wind_rot_flag);
my $tmp_file = "tmp/$$.data.tmp";

use lib "./";
use Time::Local;
require "./get_RR_file.pl";
require "./jy2mdy.pl";
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
if(0 && $qsubbed == 1) {
    my $output_file = "tmp/$data_source.$output_id.out";
# send standard out and stderr to $output_File
    use IO::Handle;
    *STDERR = *STDOUT;		# send standard error to standard out
    open OUTPUT, '>',"$output_file" or die $!;
    STDOUT->fdopen( \*OUTPUT, 'w' ) or die $!;
}

my $hrs_to_subtract = abs($ARGV[$i_arg++]) || 0;
print "HOURS TO SUBTRACT: $hrs_to_subtract \n";

my $reprocess=0;
if(defined $ARGV[$i_arg]  && $ARGV[$i_arg] > 0) {
    $reprocess=1;
    print "REPROCESSING DATA\n";
}

# look into the future up to 12 hours to get  forecasts valid in the future
my $time = time() + 12*3600 - $hrs_to_subtract*3600;
# put on 12 hour boundary
$time -= $time%(12*3600);
my @valid_times = ($time,$time-12*3600, $time-24*3600);

my $soundings_table = "${data_source}_raob_soundings";
# see if the needed tables exist
$dbh->do("use soundings_pb");
$query = qq(show tables like "$soundings_table");
print "in soundings_pb db: $query\n";
my $result = $dbh->selectrow_array($query);
print "result is $result\n";

unless($result) {
    # need to create the necessary tables
    $query = "create table soundings_pb.$soundings_table like soundings_pb.template";
    print "$query;\n";
    $dbh->do($query);
}
$dbh->do("use ruc_ua_pb");
$query = qq(show tables like "$data_source");
print "in ruc_ua_pb db: $query\n";
my $result = $dbh->selectrow_array($query);
print "result is |$result|\n";
unless($result) {
    # need to create the necessary tables
    $query = "create table $data_source like template";
    print "$query;\n";
    $dbh->do($query) or
	die "failed: $dbh->errstr()";
    print "BE SURE TO UPDATE PARTITIONS FOR REAL TIME MODELS\n";
    # find out necessary regions
    $query =<<"EOI"
select regions from ruc_ua_pb.regions_per_model where 1=1
and model = "$data_source"
EOI
;
    my @result = $dbh->selectrow_array($query);
    unless(@result) {
	die "you need to have an entry in uc_ua_pb.regions_per_model for this model.\n";
    }
    my @regions = split(/,/,$result[0]);
    print "regions read by agen_raob_sites.pl are @regions\n";
    $dbh->do("use ruc_ua_pb_sums2");

    my $iso="";
    if($data_source =~ /iso/ ||
       $data_source =~ /^rt_gfs/ ||
       $data_source =~ /^rt_ccpp/ ) {
	$iso="iso";
    }

   foreach my $region (@regions) {
	$query = "create table ruc_ua_pb_sums2.${data_source}_Areg$region like ${iso}Template_Areg0";
	print "$query;\n";
	$dbh->do($query) or
	    die "failed: $dbh->errstr()";
    }
}
$dbh->do("use soundings_pb");
$query =<<"EOI"
    replace into soundings_pb.$soundings_table
(site,time,fcst_len,s,hydro)
    values(?,?,?,?,?)
EOI
    ;
my $sth_load = $dbh->prepare($query);

# DEBUG
#@valid_times = (1267617600);

my $skip_db_load = 0;

my $station_file = "tmp/$$.new_pb_raobs.txt";
# create raobs file
my $region = 7;			# GLOBAL
my $cmd = "./create_raob_file.pl $station_file $region";
print "cmd $cmd\n";
`$cmd`;

# get fcst_lens for this model
my $query =<<"EOQ";
    select fcst_lens from ruc_ua_pb.fcst_lens_per_model
    where model = '$data_source'
EOQ
    ;
print "model is $data_source\n";
my $sth = $dbh->prepare($query);
$sth->execute();
my($fcst_lens);
$sth->bind_columns(\$fcst_lens);
unless($sth->fetch()) {
    die "You need to have an entry for this model in ruc_ua_pb.fcst_lens_per_model\n";
}
my @fcst_lens = split(",",$fcst_lens);
print("fcst_lens are @fcst_lens\n");

# DEBUG
#@fcst_lens = (-99);

foreach my $valid_time (@valid_times) {
    my $valid_date = sql_datetime($valid_time);
    print("\nLOOKING AT VALID TIME $valid_date\n");
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

	#print "looking for $fcst_len_for_db h fcst valid at $valid_date, run at $run_date\n";
	($desired_filename,$out_file,$fcst_len) =
	    &get_RR_file($run_time,$data_source,1,$desired_fcst_len,
			 $special_type);
	if($DEBUG) {
	    #print "got file |$desired_filename|\n";
	}
	unless($desired_filename) {
	    print "MODEL DATA NOT AVAILABLE for ${fcst_len_for_db}h fcst valid at $valid_date\n";
	    # don't jump to the next time, because we might need to generate running sums for this valid time
	} else {
	    print "MODEL DATA  AVAILABLE for ${fcst_len_for_db}h fcst valid at $valid_date\n";
	}
	if(soundings_loaded($soundings_table,$valid_date,$fcst_len_for_db,$special_type,$dbh)) {
	    print "$data_source soundings already loaded for ${fcst_len_for_db}h fcst valid at $valid_date\n";
	    $make_soundings=0;
	} 
	if($desired_filename) {
	    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) =
		gmtime($run_time);
	    $yday++;			# make it 1-based
	    my $atime = sprintf("%02d%03d%02d",$year%100,$yday,$hour);
	    # TURNED OFF MAILING.
	    if(0) {
		my $recipients="willian.r.moninger\@noaa.gov,Ming.Hu\@noaa.gov,Stephen.Weygandt\@noaa.gov";
		$recipients="william.r.moninger\@noaa.gov";
		open MAIL,"|/usr/sbin/sendmail -t";
		print MAIL<<EOI
To: $recipients
From: prepbufr_RAOB.processing
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
	
	if($desired_filename && ($make_soundings || $reprocess)) {
	    $found_files++;
	    ($alat1,$elon1,$elonv,$alattan,$grib_nx,$grib_ny,$grib_dx,
	     $grib_type,$grid_type,$valid_date_from_file,$fcst_len_from_file,$wind_rot_flag) =
		 get_grid($desired_filename,$thisDir,$DEBUG);
	    # put dx in km unless it is a lat-lon domain
            print "grid type: $grid_type\n";
            if($grid_type != 11 && $grid_type != 10) {
               $grib_dx /= 1000;
            } 
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
            }elsif($data_source eq "HRRRv3_EMC_iso") {
		$grib_nz = 39;
		$hydro = 0;  # check if cloud, ice variable in grib file 
            }elsif($data_source eq "HRRRv3_NCO_iso") {
		$grib_nz = 39;
		$hydro = 0;  # check if cloud, ice variable in grib file 
            }elsif($data_source eq "HRRRv4_NCO_iso") {
		$grib_nz = 39;
		$hydro = 0;  # check if cloud, ice variable in grib file 
            }elsif($data_source eq "HRRR_AKv4_NCO_iso") {
		$grib_nz = 39;
		$hydro = 0;  # check if cloud, ice variable in grib file 
            }elsif($data_source eq "RAPv4_EMC_iso") {
		$grib_nz = 39;
		$hydro = 0;  # check if cloud, ice variable in grib file 
            }elsif($data_source eq "RAPv4_NCO_iso") {
		$grib_nz = 39;
		$hydro = 0;  # check if cloud, ice variable in grib file 
            }elsif($data_source eq "RAPv5_EMC_iso") {
		$grib_nz = 39;
		$hydro = 0;  # check if cloud, ice variable in grib file 
            }elsif($data_source eq "RAPv5_NCO_iso") {
		$grib_nz = 39;
		$hydro = 0;  # check if cloud, ice variable in grib file 
            }elsif($data_source eq "RAPv5_NCO_130") {
		$grib_nz = 39;
		$hydro = 0;  # check if cloud, ice variable in grib file 
            }elsif($data_source eq "RAPv5_NCO_130_iso") {
		$grib_nz = 37;
		$hydro = 0;  # check if cloud, ice variable in grib file 
            }elsif($data_source =~ /^HRRR_iso/) {
		$grib_nz = 39;
		$hydro = 1;  # check if cloud, ice variable in grib file 
            }elsif($data_source =~ /^HRRR_OPS_iso/) {
		$grib_nz = 39;
		$hydro = 1;  # check if cloud, ice variable in grib file 
            }elsif($data_source =~ /^HRRR_AK_iso/) {
		$grib_nz = 39;
		$hydro = 1;  # check if cloud, ice variable in grib file 
            }elsif($data_source =~ /^HRRR_AK_dev_iso/) {
		$grib_nz = 39;
		$hydro = 1;  # check if cloud, ice variable in grib file 
            }elsif($data_source =~ /^HRRRv3_NCO_AK_iso/) {
		$grib_nz = 39;
		$hydro = 1;  # check if cloud, ice variable in grib file 
            }elsif($data_source =~ /^HRRR_dev3_iso/) {
		$grib_nz = 39;
		$hydro = 1;  # check if cloud, ice variable in grib file 
	    } elsif($data_source =~ /^isoRRrapx/) {
		$grib_nz = 37;
		$hydro = 0;
	    } 
	    elsif($data_source =~ /^RUA/) {
		$grib_nz = 38;
		$hydro = 1;
	    }
	    elsif($data_source eq "RAP_OPS_iso_242") {
		$grib_nz = 37;
		$hydro = 1;
	    }
	    elsif($data_source eq "RAP_iso_130") {
		$grib_nz = 39;
		$hydro = 1;
	    }
	    elsif($data_source eq "RAP_OPS_iso") {
		$grib_nz = 39;
		$hydro = 0;
		#$hydro = 1; the isobaric files for the full operational RAP does not include cloud ice as of the latest update
	    }
	    elsif($data_source eq "RAP_NCOpara_iso_242") {
		$grib_nz = 37;
		$hydro = 1;
	    }
	    elsif($data_source eq "NAM_NEST_AK" || $data_source eq "NAM_NEST_HI") {
		$grib_nz = 42;
		$hydro = 0;
	    }
	    elsif($data_source eq "GFS") {
		$grib_nz = 49;
		$hydro = 0;
	    }
	    elsif($data_source eq "FV3_GFS_EMC") {
		$grib_nz = 33;
		$hydro = 0;
	    }
	    elsif($data_source eq "HRRR_AK_OPS_iso") {
		$grib_nz = 39;
		$hydro = 0;
	    }
	    elsif($data_source eq "SAR_FV3_GSD") {
		$grib_nz = 64;
		$hydro = 0;
	    }
	    elsif($data_source eq "SAR_FV3_GSD_iso") {
		$grib_nz = 45;
		$hydro = 0;
	    }
	    elsif($data_source =~ /iso/ && $data_source =~ /^RRFS/) {
		$grib_nz = 45;
		$hydro = 0;
	    }
	    elsif($data_source =~ /^RRFS/) {
		$grib_nz = 64;
		$hydro = 0;
	    }
	    elsif($data_source =~ /iso/ && $data_source =~ /^HRRR/) {
		$grib_nz = 39;
		$hydro = 1;
	    }
	    elsif($data_source =~ /iso/) {
		$grib_nz = 37;
		$hydro = 1;
	    } elsif($data_source =~/^rt_gfs/) {
                $grib_nz = 33; 
                $hydro = 0;
	    } elsif($data_source =~/^rt_ccpp/) {
                $grib_nz = 33; 
                $hydro = 0;
            }
	    if($grib_nz < 33) {
		print "BAD NUMBER OF LEVELS: < 33.\n";
		exit(1);
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

	    $arg_unsafe = "$thisDir/new_wrgsi_soundings.x ".
		"$data_source $desired_filename $grib_type $grid_type $tmp_file $station_file ".
		"$alat1 $elon1 $elonv $alattan $grib_dx $grib_nx $grib_ny $grib_nz $hydro $wind_rot_flag";
	    
	    if($data_source =~ /iso/ || $data_source eq "NAM_NEST_AK" ||
	       $data_source eq "NAM_NEST_HI" || $data_source eq "FV3_GFS_EMC" ) {
		$arg_unsafe = "$thisDir/iso_wrgsi_soundings.x ".
		    "$data_source $desired_filename $grib_type $grid_type $tmp_file $station_file ".
		    "$alat1 $elon1 $elonv $alattan $grib_dx $grib_nx $grib_ny $grib_nz $hydro $wind_rot_flag";
#	    } elsif(!defined $alat1) {
#		$arg_unsafe = "$thisDir/rotLL_soundings.x ".
#		    "$data_source $desired_filename $grib_type $tmp_file $station_file";
#	    }
              if($grid_type == 20 || $grid_type==21 || $grid_type == 22) {
                $arg_unsafe = "$thisDir/rotLL_soundings_iso.x ".
                    "$data_source $desired_filename $grib_type $grid_type $tmp_file $station_file $hydro";
              }

	    } elsif($grid_type == 20 || $grid_type==21 || $grid_type == 22) {
		$arg_unsafe = "$thisDir/rotLL_soundings.x ".
		    "$data_source $desired_filename $grib_type $grid_type $tmp_file $station_file $hydro";

            }
	    if($data_source eq "GFS" ||
	       $data_source =~ /^rt_gfs/ ) {
		$arg_unsafe = "$thisDir/iso_wrgsi_soundings_global.x ".
		    "$data_source $desired_filename $grib_type $grid_type $tmp_file $station_file ".
		    "$alat1 $elon1 $elonv $alattan $grib_dx $grib_nx $grib_ny $grib_nz $hydro";
            }
            if($data_source =~ /^rt_ccpp/ ) {
                $arg_unsafe = "$thisDir/iso_wrgsi_soundings_global.x ".
                    "$data_source $desired_filename $grib_type $grid_type $tmp_file $station_file ".
                    "$alat1 $elon1 $elonv $alattan $grib_dx $grib_nx $grib_ny $grib_nz $hydro";
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
	    my $wmoid;
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
		    } elsif (/^      1/) {
			my @stuff = split;
			$wmoid = int($stuff[2]);
			#print("wmoid is $wmoid, name is $name\n");
			$data .= $_;
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
			print "$wmoid($hydro_length) ";

			$sth_load->execute($wmoid,$sql_date,$fcst_len_for_db,
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
	# model soundings are avaliable. see if we've already generated statistics
	if($reprocess == 0 &&
	   stats_generated($data_source,$valid_time,$fcst_len_for_db)) {
	    print "stats already generated\n";
	} else {
	    # stats not yet generated. See if raobs are avaliable
	    if(raobs_loaded($valid_time) &&
		soundings_loaded($soundings_table,$valid_date,$fcst_len_for_db,$special_type,$dbh)) {
		# we can generate comparison stats
		my $command = "~/java8/java -Xmx256m Verify3 dummy_dir $data_source ".
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
		print "RAOBs or model soundings not (yet) available for valid time $valid_date. NOT MAKING STATS\n";
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
    if(-M $file > 1.0) {	# age in days
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
	select count(*) from soundings_pb.$table
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
    $dbh->do("use ruc_ua_pb_sums2");
    my $table = "";
    my $query = qq{
	show tables from ruc_ua_pb_sums2
	where Tables_in_ruc_ua_pb_sums2 regexp '^${data_source}_A?reg[[:digit:]]*\$'};
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
select count(*) from ruc_ua_pb.RAOB
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
    if($n > 300) {
	$result = $n;
    }
    return $result;
}
    
