#!/usr/bin/perl
use strict;
use DBI;
use Time::Local;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $DEBUG=0;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

#for security, must set the PATH explicitly
$ENV{'PATH'}="";
use lib "./";

#get directory and URL
use File::Basename;
my ($basename,$thisDir) = fileparse($0);
$basename =~ m|([\-\~\.\w]*)|;  # untaint
$basename = $1;
$thisDir =~ m|([\-\~\.\w\/]*)|; # untaint
$thisDir = $1;

#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
$thisDir = $ENV{PWD};

# END OF PREAMBLE ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

my $current_list = "current_bad_aircraft.txt";

my (%N_T,%bias_T,%std_T,%bias_S,%std_S,%bias_DIR,%std_DIR,
    %std_W,%rms_W,%bias_RH,%std_RH,%entries,%model,
    %mdcrs_id,%fsl_id);

# get errors from GSD's AMDAR-RR database

#connect
$ENV{DBI_DSN} = "DBI:mysql:acars_TAM2:wolphin.fsl.noaa.gov;mysql_local_infile=1";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";
my $sth;
my($tailnum,$N_T,$avg_T,$bias_T,$std_T,
   $N_S,$avg_S,$bias_S,$std_S,$bias_DIR,$std_DIR,
   $std_W,$rms_W,$N_RH,$avg_RH,$bias_RH,$std_RH,$model,
   $mdcrs_id,$fsl_id);
my %error_list;
my %line;

# for now, eliminate pe_* tests because they seem to be too bouncy.
# and we can't do them for TAM comparisons anyway
my @vars = qw(bias_T std_T bias_S std_S bias_DIR std_DIR std_W rms_W bias_RH std_RH);

# get limits from the database
$query = qq|
    select bias_T_limit,std_T_limit,bias_S_limit,std_S_limit,
    bias_DIR_limit,std_DIR_limit,S_for_DIR_limit,std_W_limit,rms_W_limit,
    bias_RH_limit,std_RH_limit
    from limits|;
my $sth_lim = $dbh->prepare($query);
$sth_lim->execute();
my($bias_T_limit,$std_T_limit,$bias_S_limit,$std_S_limit,
    $bias_DIR_limit,$std_DIR_limit,$S_for_DIR_limit,$std_W_limit,$rms_W_limit,
    $bias_RH_limit,$std_RH_limit) =
    $sth_lim->fetchrow_array();
$sth_lim->finish();

my $stats_table = "7day";
my %limit= (
	    bias_T => $bias_T_limit,
	    std_T => $std_T_limit,
	    bias_S => $bias_S_limit,
	    std_S => $std_S_limit,
	    bias_DIR => $bias_DIR_limit,
	    std_DIR => $std_DIR_limit,
	    std_W => $std_W_limit,
	    rms_W => $rms_W_limit,
	    bias_RH => $bias_RH_limit,
	    std_RH => $std_RH_limit
	    );
foreach my $var (@vars) {
    my $test_string = "and abs($var) > $limit{$var}";
    $query =<<"EOQ";
select tailnum, tail.xid,  N_T, bias_T, std_T, 
    bias_S, std_S, bias_DIR, std_DIR, std_W, rms_W,
    bias_RH, std_RH, tail.model,
    tail.mdcrs_id
 from $stats_table,tail where
 $stats_table.xid = tail.xid
 $test_string
EOQ
    ;
    print $query;

    $sth = $dbh->prepare($query);
    $sth->execute();
    $sth->bind_columns(\$tailnum,\$fsl_id,
		       \$N_T,\$bias_T,\$std_T,
		       \$bias_S,\$std_S,\$bias_DIR,\$std_DIR,
		       \$std_W,\$rms_W,\$bias_RH,\$std_RH,
		       \$model,\$mdcrs_id);
    while($sth->fetch()) {
	$entries{$tailnum} = 1;
	$error_list{$tailnum} .= " $var";
	$N_T{$tailnum} = $N_T;
	$bias_T{$tailnum} = $bias_T;
	$std_T{$tailnum} = $std_T;
	$bias_S{$tailnum} = $bias_S;
	$std_S{$tailnum} = $std_S;
	$bias_DIR{$tailnum} = $bias_DIR;
	$std_DIR{$tailnum} = $std_DIR;
	$std_W{$tailnum} = $std_W;
	$rms_W{$tailnum} = $rms_W;
	$bias_RH{$tailnum} = $bias_RH;
	$std_RH{$tailnum} = $std_RH;
	$model{$tailnum} = $model;
	$mdcrs_id{$tailnum} = $mdcrs_id;
	$fsl_id{$tailnum} = $fsl_id;
    }
}
$sth->finish();

# remove special  TAMDAR aircraft
$query =<<"EOQ";
select tailnum, tail.xid,  N_T, bias_T, std_T, 
    bias_S, std_S, bias_DIR, std_DIR, std_W, rms_W,
    bias_RH, std_RH, 
    tail.model,tail.mdcrs_id
 from tail LEFT JOIN $stats_table on $stats_table.xid = tail.xid
 where
 n_obs > 0 
 and (tail.tailnum = "00000450" or tail.tailnum = "00000451" or
      tail.tailnum = "00000400" or tail.tailnum = "00000506")
EOQ
    ;

$sth = $dbh->prepare($query);
$sth->execute();
$sth->bind_columns(\$tailnum,\$fsl_id,
		   \$N_T,\$bias_T,\$std_T,
		   \$bias_S,\$std_S,\$bias_DIR,\$std_DIR,
		   \$std_W,\$rms_W,\$bias_RH,\$std_RH,
		   \$model,\$mdcrs_id);
while($sth->fetch()) {
    $entries{$tailnum} = 1;
    $error_list{$tailnum} .= " resrch_T_W_R";
    $N_T{$tailnum} = $N_T;
    $bias_T{$tailnum} = $bias_T;
    $std_T{$tailnum} = $std_T;
    $bias_S{$tailnum} = $bias_S;
    $std_S{$tailnum} = $std_S;
    $bias_DIR{$tailnum} = $bias_DIR;
    $std_DIR{$tailnum} = $std_DIR;
    $std_W{$tailnum} = $std_W;
    $rms_W{$tailnum} = $rms_W;
    $bias_RH{$tailnum} = $bias_RH;
    $std_RH{$tailnum} = $std_RH;
    $model{$tailnum} = $model;
    $fsl_id{$tailnum} = $fsl_id;
    $mdcrs_id{$tailnum} = $mdcrs_id;
}
$sth->finish();

# add research  TAMDAR aircraft, if necessary
foreach  my $tail ( "00000450", "00000400") {
    $entries{$tail} = 1;
    $error_list{$tail} .= " resrch_T_W_R";
    $model{$tail} = "UND_Piper";
}

# add PenAir  TAMDAR aircraft, if necessary
foreach  my $tail ("00000506" ) {
    $entries{$tail} = 1;
    $error_list{$tail} .= " PenAir_T_W_R";
    $model{$tail} = "SAAB-340";
}

# add U-Wyo King Air  TAMDAR aircraft, if necessary
foreach  my $tail ("00000451" ) {
    $entries{$tail} = 1;
    $error_list{$tail} .= " U_Wyo_T_W_R";
    $model{$tail} = "King_Air";
}

# add Forest Service TAMDAR aircraft, if necessary
foreach  my $tail ("00000499" ) {
    $entries{$tail} = 1;
    $error_list{$tail} .= " TAM_FS_T_W_R";
    $model{$tail} = "Unknown";
}

# remove all MD88 aircraft
$query =<<"EOQ";
select tailnum, tail.xid,  N_T, bias_T, std_T, 
    bias_S, std_S, bias_DIR, std_DIR, std_W, rms_W,
    bias_RH, std_RH, 
    tail.model,tail.mdcrs_id
 from tail LEFT JOIN $stats_table on $stats_table.xid = tail.xid
 where
 n_obs > 0
 and tail.model = "MD88"
EOQ
    ;

$sth = $dbh->prepare($query);
$sth->execute();
$sth->bind_columns(\$tailnum,\$fsl_id,
		   \$N_T,\$bias_T,\$std_T,
		   \$bias_S,\$std_S,\$bias_DIR,\$std_DIR,
		   \$std_W,\$rms_W,\$bias_RH,\$std_RH,
		   \$model,\$mdcrs_id);
while($sth->fetch()) {
    $entries{$tailnum} = 1;
    $error_list{$tailnum} .= " md88_W";
    $N_T{$tailnum} = $N_T;
    $bias_T{$tailnum} = $bias_T;
    $std_T{$tailnum} = $std_T;
    $bias_S{$tailnum} = $bias_S;
    $std_S{$tailnum} = $std_S;
    $bias_DIR{$tailnum} = $bias_DIR;
    $std_DIR{$tailnum} = $std_DIR;
    $std_W{$tailnum} = $std_W;
    $rms_W{$tailnum} = $rms_W;
    $bias_RH{$tailnum} = $bias_RH;
    $std_RH{$tailnum} = $std_RH;
    $model{$tailnum} = $model;
    $fsl_id{$tailnum} = $fsl_id;
    $mdcrs_id{$tailnum} = $mdcrs_id;
}
$sth->finish();

#name the reject list with the date of the latest ob
$query=<<"EOI";
select max(max_s) from $stats_table
EOI
    ;
$sth = $dbh->prepare($query);
$sth->execute();
my $max_secs;
$sth->bind_columns(\$max_secs);
$sth->fetch();
my $base_file = make_filename($max_secs);
my $ruc_rej_dir = "amdar_reject_lists";
my $out_file = "$ruc_rej_dir/$base_file";
print "out_file is $out_file\n";
open(OUT,">$out_file") ||
    die "Cannot open $out_file for writing: $!";

print OUT <<"EOI";
;First, we go through my AMDAR-TAM database table \'$stats_table\' (an error
;summary table) and look for aircraft with the following criteria:
;	    bias_T > $bias_T_limit,
;	    std_T > $std_T_limit,
;	    bias_S > $bias_S_limit,
;	    std_S > $std_S_limit,
;	    bias_DIR > $bias_DIR_limit,
;	    std_DIR > $std_DIR_limit,
;	    std_W > $std_W_limit,
;           rms_W > $rms_W_limit,
;	    bias_RH > $bias_RH_limit,
;	    std_RH > $std_RH_limit,
;Then we reject all MD88 aircraft, and TAMDAR research aircraft.
;
;tail    errors  FSL    MDCRS   N   bs_T Std_T  bs_S std_S bs_D std_D std_W rms_W bs_RH std_RH (failures)

EOI
;
foreach my $tail (sort keys %entries) {
    my $et_T = "-";
    if($error_list{$tail} =~ /_T/) {
	$et_T = "T";
    }
    my $et_S = "-";
    if($error_list{$tail} =~ /_(S|D|W)/) {
	$et_S = "W";
    }
    my $et_RH = "-";
    if($error_list{$tail} =~ /_R/) {
	$et_RH = "R";
    }
    my $mid = $mdcrs_id{$tail} || "--------";
    my $model = $model{$tail} || "Unknown";
    my $count = $N_T{$tail}; # || $ncep_count{$tail};
    printf(OUT "%-9.9s %1.1s %1.1s %1.1s %4d %8.8s ".
	   "%4d %5.1f %5.1f %5.1f %5.1f%4.0f ".
	   "%4.0f %5.1f %5.1f %5.1f %5.1f ".
	   "$model ($error_list{$tail} )\n",
	   $tail,$et_T,$et_S,$et_RH,$fsl_id{$tail},
	   $mid,$count,
	   $bias_T{$tail},$std_T{$tail},
	   $bias_S{$tail},$std_S{$tail},$bias_DIR{$tail},$std_DIR{$tail},
	   $std_W{$tail},$rms_W{$tail},
	   $bias_RH{$tail},$std_RH{$tail});
}

require "compare_rj.pl";
# compare this reject list with the previous
# and mail results
my $yesterday_file = make_filename($max_secs - 24 * 3600);
$yesterday_file = "$ruc_rej_dir/$yesterday_file";
compare_rj($out_file,$yesterday_file);

# make the new reject list the active one.
unlink("$ruc_rej_dir/$current_list") ||
    print "cannot unlink $ruc_rej_dir/$current_list: $!\n";
symlink("$base_file","$ruc_rej_dir/$current_list") ||
    print "cannot create symlink between $base_file and $current_list: $!\n";

# make reject list formatted for NCEP:
open(CUR,$out_file) ||
    die "could not open $out_file\n";
my $ncep_file = "$ruc_rej_dir/current_ncep_bad_aircraft.txt";
open(NCEP,">$ncep_file") ||
    die "cannot open $ncep_file for writing: $!";

my (%wflag,%tflag);
while(<CUR>) {
    my($tail,$tflag,$wflag,$rflag,$fsl_id,$mdcrs_id,
	$pt,$pw,$pr,$n,$bs_T,$std_T) = split;
    if($mdcrs_id eq "--------") {
	#print "fixing mdcrs_id for $tail\n";
	$mdcrs_id = $tail;
    }
    if($wflag eq "W") {
	$wflag{$mdcrs_id} = $wflag;
    }
    if($tflag eq "T" &&
       $std_T > 4.0) {
	$tflag{$mdcrs_id} = "$tflag";
    }
}
print NCEP "bad W:\n";
foreach my $id (sort keys %wflag) {
    print NCEP "$id\n";
    delete $tflag{$id};
}
print NCEP "bad T (but not bad W):\n";
foreach my $id (sort keys %tflag) {
    print NCEP "$id $tflag{$id}\n";
}


sub make_filename {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d%2.2d%2.2d_rejects.txt",
		   $year,$mon,$mday);
}
    
