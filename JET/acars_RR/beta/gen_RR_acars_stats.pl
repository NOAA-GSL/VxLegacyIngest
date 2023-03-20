#!/usr/bin/perl
#
#PBS -d .                                                                                                                 
#PBS -N RR_acars                                                                                                      
#PBS -A nrtrr                                                                                                             
#PBS -l procs=1                                                                                                           
#PBS -l partition=njet                                                                                                    
#PBS -q service                                                                                                           
#PBS -l walltime=01:00:00                                                                                                 
#PBS -l vmem=1G                                                                                                           
#PBS -M verif-amb.gsd@noaa.gov                                                                                            
#PBS -m a                                                                                                                 
#PBS -e tmp/                                                                                                              
#PBS -o tmp/ 
#
use strict;
my $thisDir = $ENV{PBS_O_WORKDIR};
unless($thisDir) {
    # we've been called locally instead of qsubbed
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $DEBUG=1;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

#for security, must set the PATH explicitly
$ENV{PATH}="/usr/bin";

# we apparently need to set LD_LIBRARY_PATH to find the intel ifort
# compiler, because verif_rotLL.x is built with shared libraries,
# to run in cron on wcron1
$ENV{LD_LIBRARY_PATH}="/opt/intel/cce/9.1.042/lib";


#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";

#clean up old files older than 24 hrs
my $tmp_dir = "RR1h_out/";
opendir(DIR,$tmp_dir) ||
    die "Can't open $tmp_dir: $!";
while(my $file = readdir DIR) {
    $file = "$tmp_dir/$file";
    $file =~/(.*)/;
    $file = $1;
    if(-M $file > 1) {
	unlink $file || print "Can't unlink $file!\n";
    }
}
closedir DIR;

my $atime;
my $run_time;
if($ARGV[0] > 020010000) {
    # an atime was input
    $atime = $ARGV[0];
} else {
    my $n_hours = abs($ARGV[0]) || 1;
    my $time = time();
    $run_time = $time - 3600*$n_hours - 1; # want 1 h forecast
    $run_time -= $run_time%3600;# put on hour boundary
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) =
	gmtime($run_time);
    $year += 1900;
    $atime = sprintf("%2.2d%3.3d%2.2d00",
		     $year%100,$yday+1,$hour);
}
require "get_RR_prs_file.pl";
my $NWP_model = "RR1h";
my($grib_file,$type,$desired_fcst_len) =
    get_RR_prs_file($run_time,$NWP_model,$DEBUG,1,0);
print "grib file is $grib_file\n";
$ENV{grib_file} = "$grib_file";

print "atime is $atime\n";
my $arg = "./verif_rotLL.x $atime $ARGV[0]";
print "$arg\n";
system($arg);

# now read the output file from the above and fill the acars_RR database

# first, prepare to update the 'tail' table
# get XTAIL file
my %id;
my %mdcrs_id;
open(X,"/public/log/QCAcars/statsDir/XTAIL") ||
    die "cannot open XTAIL: $!";
while(<X>) {
    my($tail,$id,$mdcrs_id) = split;
    if($id =~ /^\d+$/) {
	$id{$tail} = $id;
	my $ml = length($mdcrs_id);
	if(defined $ml && $ml > 0) {
	    $mdcrs_id{$tail} = $mdcrs_id;
	    #print "mdcrs_id for $tail is $mdcrs_id\n";
	}
    }
}
close X;

# use the RAWTAIL file to update SOME airlines.
# (RAWTAIL airline index is set by the QC ACARS processing, but
#  doesn't include all the airline types listed in the database.)
# this is primarily to identify SW and CO, which we can only identify
# reliably by the flight numbers found in the ACARS QC processing.
# we'll compare this with any preexisting airline identifications
# fond in the tail table.
my %airline;
my %airline_by_id = (
		     1 => 'DL',
		     2 => 'NW',
		     3 => 'UA',
		     4 => 'UP',
		     5 => 'AA',
		     6 => 'FX',
		     12 => 'TAM-Mesaba',
		     14 => 'SW',
		     15 => 'CO',
		     16 => 'TAM-PenAir',
		     18 => 'TAM-Horizon',
		     19 => 'TAM-Chautauqua',
		     20 => 'TAM-Republic',
		     21 => 'TAM-ShutAmer',
		     22 => 'TAM-other',
		     23 => 'AS-Alaska'
		     );		     
# read  RAWTAIL file, which now has airline info for each tail
open(R,"/public/log/QCAcars/statsDir/RAWTAIL") ||
    die "cannot opem RAWTAIL: $!";
while(<R>) {
    if(/^;/) {
	next;		# ignore lines starting with ;
    }
    my @s = split;
    my $tail = $s[0];
    my $airline_id = $s[12];
    if($airline_by_id{$airline_id}) {
	$airline{$tail} = $airline_by_id{$airline_id};
    }
}
close R;
# just checking
foreach my $tail (sort keys %airline) {
    #print "$tail, $airline{$tail}\n";
}

use DBI;
#set database connection parameters
require "./set_writer_acars_RR.pl";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});

my $file = "RR1h_out/$atime.data";
print " file is $file\n";
open(DATA,"$file") ||
    die "cannot open $file: $!";

my %db_id;			# hash to hold id for each tn
my %min_time;			# holds min date seen for each tn
my %max_time;			# guess
my %model;			# aircraft model
my %n_obs;			# obs for each tail
my $dtor = 0.017453;		# degrees to radians
my $query;
my $sth;

# get database id for each tailnumber
$query =<<"EOI";
select xid,tailnum,n_obs,
       UNIX_TIMESTAMP(earliest),UNIX_TIMESTAMP(latest),
       airline,model
    from tail
    where n_obs > 0
EOI
    ;
$sth = $dbh->prepare($query);
my ($db_id,$tailnum,$n_obs,$min_time,$max_time,$airline,$model);
my $max_db_id = -1;
$sth->execute();
$sth->bind_columns(\$db_id,\$tailnum,\$n_obs,\$min_time,\$max_time,
		   \$airline,\$model);
while($sth->fetch()) {
    #print "$id $tailnum $n_obs $min_time $max_time\n";
    $db_id{$tailnum} = $db_id;
    if($db_id{$tailnum} != $id{$tailnum}) {
	print STDERR "ERROR!  db ID ($id{$tailnum}) != XTAIL ($id{$tailnum}) ".
	    "for $tailnum.\nUsing XTAIL value\n";
    }
    my $id = $id{$tailnum};
    if($id > $max_db_id) {
	$max_db_id = $id;
    }
    $min_time{$tailnum} = $min_time;
    $max_time{$tailnum} = $max_time;
    $n_obs{$tailnum} = $n_obs;
    # see if we already know the airline for this tail
    if(defined $airline{$tailnum}) {
	if(defined $airline) {
	    # the tail file also knows the airline.
	    # they'd better be the same
	    if($airline{$tailnum} ne $airline) {
		print  "TROUBLE: different airlines for $tailnum: ".
		    "new: $airline{$tailnum}, old: $airline. Using old\n";
		$airline{$tailnum} = $airline;
	    }
	} else {
	    # the database doesn't yet know the airline for this tail
	    # but now its already stored for putting into the
	    # tail table later.
	    print "adding airline $airline{$tailnum} for tail $tailnum\n";
	}
    } else {
	# the ACARS QC doesn't know the airline for this tail,
	# but the database does.
	$airline{$tailnum} = $airline;
	$model{$tailnum} = $model;
    }
}

$query =<<"EOI";
replace into acars
(aid, date, xid, lat, lon, press, t, dir, s, hdg, ul, vx, mach,
rh, ht, ap_id, up_dn, rh_unc, tas, source)
values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
EOI
    ;
my $sth_load_acars = $dbh->prepare($query);

$query =<<"EOI";
select aid from acars where
    date = ? and
    xid = ? and
    lat = ? and
    lon = ? and
    press = ?
EOI
    ;
my $sth_find_acars = $dbh->prepare($query);

$query = qq[select last_insert_id()];
my $sth_get_last_id = $dbh->prepare($query);

$query =<<"EOI";
select aid from $NWP_model where
    aid = ?
EOI
    ;
my $sth_find_NWP_acars = $dbh->prepare($query);

$query =<<"EOI";
replace into $NWP_model
    (tf,dirf,sf,ulf,vxf,vdiff,rhf,htf,aid) values(?,?,?,?,?,?,?,?,?)
EOI
    ;
my $sth_load_NWP_model = $dbh->prepare($query);

$query =<<"EOI";
update $NWP_model set
    tf = ?,
    dirf = ?,
    sf = ?,
    ulf = ?,
    vxf = ?,
    vdiff = ?,
    rhf = ?,
    htf = ?
  where aid = ?
EOI
    ;
my $sth_update_NWP_model = $dbh->prepare($query);

my $acars_loaded=0;
my $model_values_loaded=0;
    while(<DATA>) {
    unless(/^\./) {
	#print;
	my ($time,$dum1,$tail,$lat,$lon,$pres,$t,$dum2,$tf,
	    $dir,$dum3,$dirf,$s,$dum4,$sf,$hdg,$mach,$dum5,
	    $rh,$dum6,$rhf,$ht,$dum7,$htf,
	    $ap_id,$up_dn,$rh_unc,$tas,$dataSource) = split;
	unless (defined $id{$tail}) {
	    print "ERROR: no XTAIL entry for $tail.  Ignoring\n";
	    next;
	} else {
	    # we've seen this tail before.  Update dates
	    if($time > $max_time{$tail}) {
		$max_time{$tail} = $time;
	    }
	    if(!defined $min_time{$tail} ||
	       $min_time{$tail} == 0 ||
	       $time < $min_time{$tail}) {
		$min_time{$tail} = $time;
	    }
	    $n_obs{$tail}++;
	}
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

	# get id of this acars record
	# (can't use last_insert_id 'cuz this acars may have been
	# stored previously.
	$sth_find_acars->execute($date,$id{$tail},$ilat,$ilon,$ipres);
	if($id{$tail} == 866400000) {
	    print("finding $date,$id{$tail},$ilat,$ilon,$ipres,$it,".
		  "$idir,$is,$ihdg,$iul,$ivx,$imach,".
		  "$irh,$iht,$ap_id,$up_dn\n");
	}
	my ($aid_acars) = $sth_find_acars->fetchrow_array();
	# if $aid is undef, this will load the acars record,
	# otherwise, it will update it.
	$sth_load_acars->execute($aid_acars,
				 $date,$id{$tail},$ilat,$ilon,$ipres,$it,
				 $idir,$is,$ihdg,$iul,$ivx,$imach,
				 $irh,$iht,$ap_id,$up_dn,$irh_unc,
				 $itas,$dataSource);
	$acars_loaded++;
	# get the acars record if it has just been created
	unless($aid_acars) {
	    $sth_get_last_id->execute();
	    ($aid_acars) = $sth_get_last_id->fetchrow_array();
	}
	#see if this acars record is already in the model file
	$sth_find_NWP_acars->execute($aid_acars);
	my ($aid_NWP) = $sth_find_NWP_acars->fetchrow_array();
	if($aid_NWP) {
	    if($aid_NWP != $aid_acars) {
		die "different acars IDs: $aid_NWP, $aid_acars\n";
	    }
	    #print "updated acars $aid_acars in table $NWP_model\n";
	    $sth_update_NWP_model->execute($itf,$idirf,$isf,$iulf,$ivxf,
					   $ivdiff,$irhf,$ihtf,$aid_acars);
	    $model_values_loaded++;
	} else {
	    #print "inserted acars $aid_acars into table $NWP_model\n";
	    $sth_load_NWP_model->execute($itf,$idirf,$isf,$iulf,$ivxf,
					 $ivdiff,$irhf,$ihtf,$aid_acars);
	    $model_values_loaded++;
	}
    }
}
close(DATA);

print "$acars_loaded acars obs loaded; $model_values_loaded model values loaded\n";

$sth_load_acars->finish();
$sth_find_acars->finish();
$sth_get_last_id->finish();
$sth_find_NWP_acars->finish();
$sth_load_NWP_model->finish();
$sth_update_NWP_model->finish();
$query =<<"EOI"
insert into tail
 (xid,tailnum,n_obs,earliest,latest,airline,mdcrs_id) values(?,?,?,?,?,?,?)
 on duplicate key update
 n_obs = ?,
 earliest = ?,
 latest = ?,
 airline = ?,
 mdcrs_id = ?
EOI
    ;
$sth = $dbh->prepare($query);

foreach my $tail (sort keys %id) {
    my $min_date = sql_date($min_time{$tail});
    my $max_date = sql_date($max_time{$tail});
    if($n_obs{$tail} > 0) {
	$sth->execute($id{$tail},$tail,$n_obs{$tail},$min_date,$max_date,
		      $airline{$tail},$mdcrs_id{$tail},
		      $n_obs{$tail},$min_date,$max_date,$airline{$tail},$mdcrs_id{$tail});
    }
}

$dbh->disconnect();
print "NORMAL TERMINATION\n";
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
exit 0;

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


