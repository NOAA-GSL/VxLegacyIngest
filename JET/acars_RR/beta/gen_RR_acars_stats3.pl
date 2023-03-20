#!/usr/bin/perl
#
#SBATCH -J ACARS_verif
#SBATCH --mail-user=jeffrey.a.hamilton@noaa.gov
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 8
#SBATCH -p vjet,xjet
#SBATCH -t 00:50:00
#SBATCH -D .
#SBATCH --mem=16G
#SBATCH -o tmp2/ACARS_verif.oe%j
#

use strict;
my $thisDir = $ENV{SLURM_SUBMIT_DIR};
unless($thisDir) {
    # we've been called locally instead of qsubbed
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}
my $output_id = $ENV{SLURM_JOB_ID} || $$;
# just get numerical part
$output_id =~ /((\d)+)/;
$output_id = $1;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $DEBUG=1;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

# we apparently need to set LD_LIBRARY_PATH to find the intel ifort
# compiler, because verif_rotLL.x is built with shared libraries,
# to run in cron on wcron1
$ENV{LD_LIBRARY_PATH}="/opt/intel/cce/9.1.042/lib";

#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";

my $tmp_dir = "$thisDir/tmp2/";
my $f_out_file = "$tmp_dir/$output_id.data";

my $atime;
my $run_time;
my $valid_time;
my $i_arg=0;
my $model = $ARGV[$i_arg++];
my $n_hours = abs($ARGV[$i_arg++]) || 1;
my $reprocess = $ARGV[$i_arg++] || 0;
my $time = time();
$time -= $time%3600;	# put on an hour boundary
my $first_time = $time - 3600*$n_hours;
my @valid_times = ($first_time,$first_time - 1*3600,$first_time - 3*3600);

my @fcst_lens = (0,1,3,6,9,12);
if($model eq "GFS_OPS_iso") {
    @fcst_lens = (0,3,6,9,12,18,24,36,48);
} elsif($model eq "FIM_iso_4") {
    @fcst_lens = (0,6,12,18,24,36,48);
}
foreach my $fcst_len (@fcst_lens) {
foreach $valid_time (@valid_times) {
$run_time = $valid_time - $fcst_len*3600;
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) =
    gmtime($valid_time);
$year += 1900;
$atime = sprintf("%2.2d%3.3d%2.2d00",
		 $year%100,$yday+1,$hour);
print("\nPROCESSING $model ${fcst_len}h forecast valid at ".gmtime($valid_time)."\n");

if(!$reprocess && already_processed($model,$valid_time,$fcst_len)) {
    print "ALREADY PROCESSED\n";
} else { # process this fcst/valid-time

require "get_RR_prs_file.pl";
require "get_grid.pl";
my($grib_file,$grid_type,$desired_fcst_len) =
    get_RR_prs_file($run_time,$model,$DEBUG,$fcst_len,0);
my $age = -M $grib_file; # time in days since last modification time
#print "age is $age\n\n";
if($age > 0.01) { # file older than 14 minutes (to avoid reading partial files)
    my($la1,$lo1,$lov,$latin1,$nx,$ny,$dx,$grib_type,$grid_type,$valid_date_from_file,$fcst_proj) =
	get_grid($grib_file,$thisDir,$DEBUG);
    my $grib_nz;
    if($model =~ /^HRRR/) {
	$grib_nz = 37;
    } elsif($model =~ /_221/) {
	$grib_nz = 37;		# 221 grid (NAM) but only up to 100 mb!
    } elsif($model =~/OPS/) {
	$grib_nz = 37;
    } elsif($model eq "RAPv3_NCO_iso_130") {
	$grib_nz = 37;
    }elsif($model eq "RAP_iso_130") {
	$grib_nz = 37;
    } elsif($model eq "FIM_iso_4") {
	$grib_nz = 40;
    } elsif($model =~ /^RTMA/) {
	$grib_nz = 37;
    } elsif($model =~ /iso/) {
	$grib_nz = 37;
    }
    if(1) {
	print "|$la1| |$lo1| |$lov| |$latin1| ".
	    "|$nx| |$ny| |$dx|\n";
    }
    $ENV{grib_file} = "$grib_file";       # pass grib file name to verif_rotLL.x

my $load_data_file = "$tmp_dir/$model.$valid_time.$fcst_len.sql_data.writing";
print "LOAD FILE: $load_data_file\n";
open(LDF,">$load_data_file") ||
    die "cannot open $load_data_file: $!";

print "grib file is $grib_file\n";
print "atime (treated as valid time here) is $atime\n";
my $arg;
    if($model eq "GFS_OPS_iso") {
	$arg = "./verif_gfs.x $atime $model $valid_time $grib_file $f_out_file";
    } elsif($model eq "FIM_iso_4") {
	$arg = "./verif_fim.x $atime $model $valid_time $grib_file $f_out_file";
    } elsif($grid_type == 20) {
	# old rotated LL grid
	$arg = "./verif_rotLL.x $atime $model $f_out_file";
    } elsif($grid_type == 21) {
	# NEW rotLL grid
	$la1 = 54.0;		# lat_0_deg
	$lo1 = -106.0;		# lon_0_deg
	$lov = -10.5906;	# lat_g_SW_deg
	$latin1 = -139.0858;	# lon_g_SW_deg
	$dx = 13.54508;
	$grib_nz = 37;
 	$arg = "./verif5.x $atime $model $grib_file $grib_type $grid_type $f_out_file ".
	    "$la1 $lo1 $lov $latin1 $dx $nx $ny $grib_nz";
    } elsif($grid_type == 1) {
	# Lambert Conformal Conic with 1 std parallel
	$arg = "./verif5.x $atime $model $grib_file $grib_type $grid_type $f_out_file ".
	    "$la1 $lo1 $lov $latin1 $dx $nx $ny $grib_nz";
    }
print "$arg\n";
system($arg);

open(DATA,"$f_out_file") ||
    die "cannot open $f_out_file: $!";

my %db_id;			# hash to hold id for each tn
my %min_time;			# holds min date seen for each tn
my %max_time;			# guess
my %n_obs;			# obs for each tail
my $dtor = 0.017453;		# degrees to radians

while(<DATA>) {
    unless(/^\./) {
	#print;
	my ($time,$dum1,$tail,$lat,$lon,$pres,$t,$dum2,$tf,
	    $dir,$dum3,$dirf,$s,$dum4,$sf,$hdg,$mach,$dum5,
	    $rh,$dum6,$rhf,$ht,$dum7,$htf,
	    $ap_id,$up_dn,$rh_unc,$tas,$dataSource) = split;

	# get longitudinal and transverse components
	my ($iul,$iulf,$ivx,$ivxf,$ihdg,$ivdiff);
	if($hdg >= 360 || $dir > 900 || $dirf > 900) {
	    # no heading.  cannot calculate components wrt path
	    $ihdg = undef;
	    $iul = undef;
	    $iulf =  undef;
	    $ivx =  undef;
	    $ivxf =  undef;
	    $ivdiff = undef;
	} else {
	    $ihdg = round($hdg*100);
	    my $delta_theta = ($hdg-$dir)*$dtor;
	    my $ul = - $s*100*cos($delta_theta);
	    my $vx = - $s*100*sin($delta_theta);
	    my $delta_thetaf = ($hdg-$dirf)*$dtor;
	    my $ulf = - $sf*100*cos($delta_thetaf);
	    my $vxf = - $sf*100*sin($delta_thetaf);
	    my $vdiff = sqrt(($ul-$ulf)**2+($vx-$vxf)**2);
	    $ivdiff = round($vdiff);
	    $iul = round($ul);
	    $iulf = round($ulf);
	    $ivx = round($vx);
	    $ivxf = round($vxf);
	}
	    
	my $date = sql_date($time);
	my $ilat = round($lat*100);
	while($lon > 180) {$lon -= 360;}
	while($lon < -180) {$lon += 360;}
	my $ilon = round($lon*100);
	my $ipres = round($pres*10);
	my($it,$itf);
	if($t > 900) {
	    $it = undef;
	} else {
	    $it = round($t*100);
	}
	if($tf > 900) {
	    $itf = undef;
	} else {
	    $itf = round($tf*100);
	}
	my ($idir,$idirf);
	if($dir > 900) {
	    $idir = undef;
	} else {
	    $idir = round($dir*100);
	}
	if($dirf > 900) {
	    $idirf = undef;
	} else {
	    $idirf = round($dirf*100);
	}
	my ($is,$isf);
	if($s > 900) {
	    $is = undef;
	} else {
	    $is = round($s*100);
	}
	if($sf > 900) {
	    $isf = undef;
	} else {
	    $isf = round($sf*100);
	}
	my $imach;
	if($mach > 9000) {
	    $imach =  undef;
	} else {
	    $imach = round($mach*1000);
	}
	my ($irh,$irhf);
	if($rh > 900) {
	    $irh = undef;
	} else {
	    $irh = round($rh);
	}
	if($rhf > 900) {
	    $irhf = undef;
	} else {
	    $irhf = round($rhf);
	}
	my($iht,$ihtf);
	if($ht > 9000) {
	    $iht = undef;
	} else {
	    $iht = round($ht);
	}
	if($htf > 9000) {
	    $ihtf = undef;
	} else {
	    $ihtf = round($htf);
	}
	if($ap_id == 0) {
	    $ap_id = undef;
	}
	if($up_dn == 0) {
	    $up_dn = undef;
	}
	my $irh_unc;
	if($rh_unc > 9000) {
	    $irh_unc = undef;
	} else {
	    $irh_unc = round($rh_unc);
	}
	my $itas;
	if($tas > 9000) {
	    $itas = undef;
	} else {
	    $itas = round($tas/2);
	}

	    print(LDF "$time,$fcst_len,$tail,$ilat,$ilon,$ipres,".code_nulls($it).",".code_nulls($idir).",".code_nulls($is).
		  ",".code_nulls($ihdg).",".code_nulls($iul).",".code_nulls($ivx).",".code_nulls($imach).",".code_nulls($irh).
		  ",".code_nulls($iht).",".code_nulls($ap_id).",". code_nulls($up_dn).",".code_nulls($itf).
		  ",".code_nulls($idirf).",".code_nulls($isf).",".code_nulls($iulf).",".code_nulls($ivxf).",".code_nulls($ivdiff).
		  ",".code_nulls($irhf).",".code_nulls($ihtf)."\n");
	    print("INSERT INTO LOAD DATA: $time,$fcst_len,$tail,$ilat,$ilon,$ipres,".code_nulls($it).",".code_nulls($idir).",".code_nulls($is).
		  ",".code_nulls($ihdg).",".code_nulls($iul).",".code_nulls($ivx).",".code_nulls($imach).",".code_nulls($irh).
		  ",".code_nulls($iht).",".code_nulls($ap_id).",". code_nulls($up_dn).",".code_nulls($itf).
		  ",".code_nulls($idirf).",".code_nulls($isf).",".code_nulls($iulf).",".code_nulls($ivxf).",".code_nulls($ivdiff).
		  ",".code_nulls($irhf).",".code_nulls($ihtf)."\n");
    }
}
close(DATA);
close(LDF);
my $written_file = $load_data_file;
$written_file =~ s/writing$/written/;
print "WRITTEN FILE: $written_file\n";
rename($load_data_file,$written_file) ||
    die "could not rename file $load_data_file to $written_file: $!";

unlink $f_out_file ||
    print "can't unlink $f_out_file $!\n";

} else { # end if grib_file
    print "GRIB FILE NOT AVAILABLE\n";
}
} # end test of already processed
} # end loop over fcst_len s
} #end loop over valid times

# clean up tmp directory
opendir(DIR,"tmp2") ||
    die "cannot open tmp2/: $!\n";
my @allfiles = grep !/^\.\.?$/,readdir DIR;
foreach my $file (@allfiles) {
    $file = "$tmp_dir/$file";
    #print "file is $file\n";
    # untaint
    $file =~ /(.*)/;
    $file = $1;
    if(-M $file > 2) {
	print "unlinking $file\n";
	unlink "$file" || print "Can't unlink $file $!\n";
    }
}
closedir DIR;
print "NORMAL TERMINATION\n";
exit 0;

sub already_processed {
    # this only works within 24 h of the original processing,
    # because files in tmp/ are scrubbed (see just above) after 1 day
    my($model,$valid_secs,$fcst_len) = @_;
    my $result = 0;
    my $file = "tmp2/$model.$valid_secs.$fcst_len.sql_data.loaded";
    if(-r $file &&
	-s $file > 0) {
	$result = 1;
    }
    return($result);
}
    
sub code_nulls {
    my $val = shift;
    my $result = '\\N';
    if(defined $val) {
	$result = $val;
    }
    return $result;
}
	
sub round {
    my $x = shift;
    return int($x + ($x >= 0 ? 0.5 : -0.5));
}

sub sql_date {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
		   $year,$mon,$mday,$hour,$min,$sec);
}

sub jy2mdy {
    no strict;
    my ($i,$julday,$leap,$timeSecs);
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
    ($julday,$year)=@_;
    
    #daytab holds number of days per month for regular and leap years
    my (@daytab) =(0,31,28,31,30,31,30,31,31,30,31,30,31,
                      0,31,29,31,30,31,30,31,31,30,31,30,31);
    my (@month)=(Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec);
    my (@day)=(Sun,Mon,Tue,Wed,Thu,Fri,Sat);

    #see if year was defined
    if($year == 0) {
        $timeSecs=time();
        ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
            = gmtime($timeSecs);
        $year += 1900;
    } elsif ($year < 1000) {
        #2-digit year was (probably) input
        if($year > 70) {
            $year += 1900;
        } else {
            $year += 2000;
        }
    }

    #see if the year is a leap year
    $leap = ($year%4 == 0 && $year%100 != 0) || ($year%400 == 0);
    my $tt = $year%400;
    for($i=1,$mday = $julday ; $mday  > $daytab[$i + 13 * $leap]  ; $i++) {
        $mday -= $daytab[$i + 13 * $leap];
    }
    $mon=$i-1;
    my $dum;
    $timeSecs=timegm(0,0,0,$mday,$mon,$year);
    ($dum,$dum,$hour,$mday,$mon,$dum,$wday,$yday,$isdst)
        = gmtime($timeSecs);
    use strict;
    #return a 4 digit year
    ($mday,$mon,$year);
}
