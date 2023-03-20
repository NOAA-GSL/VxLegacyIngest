#!/usr/bin/perl
use strict;
use lib "/misc/whome/moninger/DBD-mysql-2.9004/lib";
use lib "/misc/whome/moninger/DBD-mysql-2.9004/blib/arch/auto/DBD/mysql";
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

#connect
$ENV{DBI_DSN} = "DBI:mysql:madis3:wolphin.fsl.noaa.gov;mysql_local_infile=1";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";
my $sth;
my $stats_table = "RR1h_7day";
my $min_N = 20;

# get limits from the database
# NO -- USE STAN'S NEW CUTOFFS SET BY HAND BELOW
# the limits are in English units
$query = qq|select 
    bias_T_limit,std_T_limit,bias_S_limit,
    std_S_limit,bias_DIR_limit,std_DIR_limit,S_for_DIR_limit,
    rms_W_limit,bias_Td_limit,std_Td_limit
    from limits|;
#print "$query;\n";

my $sth_lim = $dbh->prepare($query);
$sth_lim->execute();
my($bias_T_limit,$std_T_limit,$bias_S_limit,$std_S_limit,
    $bias_DIR_limit,$std_DIR_limit,$S_for_DIR_limit,$rms_W_limit,
    $bias_Td_limit,$std_Td_limit) =
    $sth_lim->fetchrow_array();
$sth_lim->finish();

# bring out values in metric usings, but the 'if' clauses uses English units
#$query =<<"EOQ";
#select name,net,min_time ,max_time,
#   if(N_T > $min_N and bias_T < $bias_T_limit  and std_T < $std_T_limit, 1,0) as T_flag,
#   N_T,(avg_T-32)/1.8,bias_T/1.8,std_T/1.8,
#   if(N_S > $min_N and bias_S < $bias_S_limit and std_S < $std_S_limit and bias_DIR < $bias_DIR_limit
#      and std_DIR < $std_DIR_limit and rms_W < $rms_W_limit,1,0) as W_flag,
#   N_S,avg_S*0.447,bias_S*0.447,std_S*0.447,N_DIR,bias_DIR,std_DIR,
#   rms_W*0.447,
#   if(N_Td > $min_N and bias_Td < $bias_Td_limit and std_Td < $std_Td_limit,1,0) as Td_flag,
#   N_Td,(avg_Td-32)/1.8,bias_Td/1.8,std_Td/1.8
# from $stats_table as m
#EOQ
#;

# Stan's new cutoff
$bias_T_limit = 1; 		# K
$std_T_limit = 2.5; 		# K
$bias_Td_limit = 1;		# K
$std_Td_limit = 2.5;
$bias_S_limit = 0.5;         # m/s
$std_S_limit = 2.2;           # m/s
$bias_DIR_limit = 20;       # degrees
$std_DIR_limit =  90;
$rms_W_limit = 3.0;         # m/s

#  $bias_T_limit/1.8,$std_T_limit/1.8,$bias_S_limit*0.447,$std_S_limit*0.447,
#    $bias_DIR_limit,$std_DIR_limit,$rms_W_limit*0.447,$bias_Td_limit/1.8,$std_Td_limit/1.8);

$query =<<"EOQ";
select name,net,min_time ,max_time,
   if(N_T > $min_N and bias_T < $bias_T_limit*1.8  and std_T < $std_T_limit*1.8, 1,0) as T_flag,
   N_T,(avg_T-32)/1.8,bias_T/1.8,std_T/1.8,
   if(N_S > $min_N and bias_S < $bias_S_limit/0.447 and std_S < $std_S_limit/0.447 and bias_DIR < $bias_DIR_limit
      and std_DIR < $std_DIR_limit and rms_W < $rms_W_limit/0.447,1,0) as W_flag,
   N_S,avg_S*0.447,bias_S*0.447,std_S*0.447,N_DIR,bias_DIR,std_DIR,
   rms_W*0.447,
   if(N_Td > $min_N and bias_Td < $bias_Td_limit*1.8 and std_Td < $std_Td_limit*1.8,1,0) as Td_flag,
   N_Td,(avg_Td-32)/1.8,bias_Td/1.8,std_Td/1.8
 from $stats_table as m
EOQ
;

print "$query\n";

my $sth = $dbh->prepare($query);
$sth->execute();
my($name,$net,$min_sec,$max_sec,
   $T_flag,$N_T,$avg_T,$bias_T,$std_T,
   $W_flag,$N_S,$avg_S,$bias_S,$std_S,$N_DIR,$bias_DIR,$std_DIR,
   $rms_W,
   $Td_flag,$N_Td,$avg_Td,$bias_Td,$std_Td);
$sth->bind_columns(\$name,\$net,\$min_sec,\$max_sec,
		   \$T_flag,\$N_T,\$avg_T,\$bias_T,\$std_T,
		   \$W_flag,\$N_S,\$avg_S,\$bias_S,\$std_S,
		   \$N_DIR,\$bias_DIR,\$std_DIR,
		   \$rms_W,
		   \$Td_flag,\$N_Td,\$avg_Td,\$bias_Td,\$std_Td);
my %out;
my $min_sec_found = 1e99;
my $max_sec_found = 0;
my $good_count=0;
my %net;
my %dup;
my $good_W=0;
my $good_T=0;
my $good_Td=0;
while($sth->fetch()) {
    $good_count++;
    if($net{$name}) {
	$dup{$name}++;
    }
    $net{$name} .= "$net ";
    if($min_sec < $min_sec_found) {
	$min_sec_found = $min_sec;
    }
    if($max_sec > $max_sec_found) {
	$max_sec_found = $max_sec;
    }
    my $min_date = sql_date($min_sec);
    my $max_date = sql_date($max_sec);
    if($W_flag) {
	$good_W++;
    }
    if($T_flag) {
	$good_T++;
    }
    if($Td_flag) {
	$good_Td++;
    }

    my $key = 4*$W_flag + 2*$T_flag + $Td_flag;
    $key .= " $name $net";
    $out{$key}=
    sprintf(qq|%10.10s %1d %1d %1d %15.15s%3d %5.1f |.
	   qq|%5.1f |.
	   qq|%5.1f %3d %5.1f |.
	   qq|%5.1f |.
	   qq|%5.1f %3d |.
	   qq|%4.0f |.
	   qq|%4.0f |.
	   qq|%5.1f %3d  %5.1f |.
	   qq|%5.1f |.
	   qq|%5.1f |.
	   qq|$min_date  $max_date|,
	   $name,$W_flag,$T_flag,$Td_flag,$net,$N_T,$avg_T,$bias_T,$std_T,
	   $N_S,$avg_S,$bias_S,$std_S,$N_DIR, $bias_DIR,$std_DIR,
	   $rms_W,
	   $N_Td,$avg_Td,$bias_Td,$std_Td);
}
$sth->finish();
$dbh->disconnect();
foreach my $name (sort keys %dup) {
    print ";DUP: $name in nets: $net{$name}\n";
}
my $min_date_found = sql_date($min_sec_found);
my $max_date_found = sql_date($max_sec_found);
my $max_day_found = sql_date($max_sec_found,1);

# name the uselist file with the max_date_found
my $base_file = "${max_day_found}_meso_uselist.txt";
my $uselist_dir = "mesonet_uselists";
my $out_file = "$uselist_dir/$base_file";
print "out file is $out_file\n";
open(OUT,">$out_file") ||
    die "Cannot open $out_file for writing: $!";    
print OUT qq{; First, we go through  table \'$stats_table\' and\n}.
    qq{; look for stations satisfying the following criteria for\n}.
    qq{; wind, temperature, and dewpoint separately\n};
printf(OUT ";\tN_T > $min_N\n".
	";\tbias_T < %.2f K\n".
	";\tstd_T < %.2f K\n".
	";\tN_S > $min_N\n".
	";\tbias_S < %.2f m/s\n".
	";\tstd_S < %.2f m/s\n".
	";\tbias_DIR < %.0f\n".
	";\tstd_DIR < %.0f\n".
	";\trms_W < %.2f m/s\n".
	";\tN_Td > $min_N\n".
	";\tbias_Td < %.2f K\n".
	";\tstd_Td < %.2f K\n",
	$bias_T_limit,$std_T_limit,$bias_S_limit,$std_S_limit,
	$bias_DIR_limit,$std_DIR_limit,$rms_W_limit,$bias_Td_limit,$std_Td_limit);

print OUT "; mesonet data for $min_date_found to $max_date_found\n";
#print OUT "; taken between 18Z and 21Z (inclusive)\n";

print OUT "; good_W: $good_W, good_T: $good_T, good_Td: $good_Td\n";
print OUT ";    name  good         net            ----------T--------- -----------S--------- ".
    " -----DIR----    W   ----------Td---------        first                 last\n";
print OUT ";              W T Td                         N   avg   bias   std  N    avg   bias  std".
    "   N bias  std   std  N    avg   bias   std\n";
my $i=0;
foreach my $key (sort my_way keys %out) {
    my($flag,$name,$net) = split(/\W/,$key);
    if($flag > 0) {
	print OUT "$out{$key}\n";
    }
}
close OUT;

my $current_list = "$uselist_dir/current_mesonet_uselist.txt";
unlink("$current_list") ||
    print "cannot unlink: $!";
symlink($base_file,$current_list) ||
    print "cannot create symlink: $!";

sub my_way {
    my($flag1,$name1,$net1) = split(/\W/,$a);
    my($flag2,$name2,$net2) = split(/\W/,$b);
    my $diff = $flag2 - $flag1;
    if($diff == 0) {
	$diff = $name2 lt $name1 ? 1 : -1;
    }
    if($diff == 0) {
	$diff = $net2 lt $net1 ? 1 : -1;
    }
    return($diff);
}

sub sql_date {
    my($time,$day_only) = @_;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    if($day_only) {
	return sprintf("%4d-%2.2d-%2.2d",
		       $year,$mon,$mday);
    } else {
	return sprintf("%4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
		       $year,$mon,$mday,$hour,$min,$sec);
    }
}

sub make_filename {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d%2.2d%2.2d_rejects.txt",
		   $year,$mon,$mday);
}
    
