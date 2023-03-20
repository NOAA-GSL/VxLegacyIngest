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
my $stats_table = "RAP_NCEP_full_7day";
my $min_N = 20;

# get limits from the database
# the limits table is in mks/Celsius units
# but the stats table is in English units
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

$query =<<"EOQ";
select sta_id,name,net,min_time ,max_time,
   if(N_T > $min_N and abs(bias_T) < $bias_T_limit*1.8  and std_T < $std_T_limit*1.8, 1,0) as T_flag,
   N_T,(avg_T-32)/1.8,bias_T/1.8,std_T/1.8,
   if(N_S > $min_N and abs(bias_S) < $bias_S_limit/0.447 and std_S < $std_S_limit/0.447 and abs(bias_DIR) < $bias_DIR_limit
      and std_DIR < $std_DIR_limit and rms_W < $rms_W_limit/0.447,1,0) as W_flag,
   N_S,avg_S*0.447,bias_S*0.447,std_S*0.447,N_DIR,bias_DIR,std_DIR,
   rms_W*0.447,
   if(N_Td > $min_N and abs(bias_Td) < $bias_Td_limit*1.8 and std_Td < $std_Td_limit*1.8,1,0) as Td_flag,
   N_Td,(avg_Td-32)/1.8,bias_Td/1.8,std_Td/1.8
 from $stats_table as m
EOQ
;

print "$query\n";

my $sth = $dbh->prepare($query);
$sth->execute();
my($sta_id,$name,$net,$min_sec,$max_sec,
   $T_flag,$N_T,$avg_T,$bias_T,$std_T,
   $W_flag,$N_S,$avg_S,$bias_S,$std_S,$N_DIR,$bias_DIR,$std_DIR,
   $rms_W,
   $Td_flag,$N_Td,$avg_Td,$bias_Td,$std_Td);
$sth->bind_columns(\$sta_id,\$name,\$net,\$min_sec,\$max_sec,
		   \$T_flag,\$N_T,\$avg_T,\$bias_T,\$std_T,
		   \$W_flag,\$N_S,\$avg_S,\$bias_S,\$std_S,
		   \$N_DIR,\$bias_DIR,\$std_DIR,
		   \$rms_W,
		   \$Td_flag,\$N_Td,\$avg_Td,\$bias_Td,\$std_Td);
my %out;
my %out_db;
my %out_archive_db;
my $min_sec_found = 1e99;
my $max_sec_found = 0;
my %good_count;
my %net;
my %dup;
my %good_W;
my %good_T;
my %good_Td;
while($sth->fetch()) {
    my $is_dup = 0;
    if($net{"$name $net"}) {
	$is_dup = 1;
	$dup{"$name $net"}++;
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
    if(!$is_dup && $W_flag) {
	$good_W{$net}++;
    }
    if(!$is_dup && $T_flag) {
	$good_T{$net}++;
    }
    if(!$is_dup && $Td_flag) {
	$good_Td{$net}++;
    }
    my $key1 = 4*$W_flag + 2*$T_flag + $Td_flag;
    my $key2 = "$key1 $name $net";
    my $str2 = sprintf(qq|%10.10s %1d %1d %1d %15.15s%3d %5.1f |.
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
    $out{$key2}=$str2;
    if(!$is_dup && $key1 > 0) {
	$good_count{$net}++;
	$out_db{$sta_id} = "$sta_id,$name,$net,$W_flag,$T_flag,$Td_flag,$min_sec,$max_sec";
        if($net == 'METAR'){
	   $out_archive_db{$sta_id} = "$sta_id,$name,$min_sec,$max_sec,$T_flag,$bias_T_limit,$std_T_limit,$N_T,$avg_T,$bias_T,$std_T,$Td_flag,$bias_Td_limit,$std_Td_limit,$N_Td,$avg_Td,$bias_Td,$std_Td,$W_flag,$bias_S_limit,$std_S_limit,$bias_DIR_limit,$std_DIR_limit,$S_for_DIR_limit,$rms_W_limit,$N_S,$avg_S,$bias_S,$std_S,$N_DIR,$bias_DIR,$std_DIR,$rms_W";
        }
	if($name eq "WPK") {
	    print "$str2\n";
	}
    }
}
$sth->finish();
foreach my $name (sort keys %dup) {
    print ";DUP: $name in nets: $net{$name}\n";
}
my $min_date_found = sql_date($min_sec_found);
my $max_date_found = sql_date($max_sec_found);
my $max_day_found = sql_date($max_sec_found,1);

my $out_db_file = "tmp/$$.out_db.txt";
my $out_archive_db_file = "tmp/$$.out_archive_db.txt";
print "out_db file is $out_db_file\n";
open(OUT_DB,">$out_db_file") ||
     die "Cannot open $out_db_file for writing: $!";
foreach my $key (keys %out_db) {
    print OUT_DB "$out_db{$key}\n";
}
close OUT_DB;
print "out_archive_db file is $out_archive_db_file\n";
open(OUT_ARCHIVE_DB,">$out_archive_db_file") ||
     die "Cannot open $out_archive_db_file for writing: $!";
foreach my $key (keys %out_archive_db) {
    print OUT_ARCHIVE_DB "$out_archive_db{$key}\n";
}
close OUT_ARCHIVE_DB;
$query =<<"EOI"
load data local infile '$out_archive_db_file'
into table rap_ops_uselist_archive
fields terminated by ','
EOI
    ;
print "$query\n";
my $rows = $dbh->do($query);
print "$rows rows loaded into rap_ops_uselist_archive\n";
$query = "drop table if exists uselist_tmp";
print "$query\n";
$dbh->do($query);
$query = "create  table uselist_tmp like uselist";
print "$query\n";
$dbh->do($query);
$query =<<"EOI"
load data local infile '$out_db_file'
into table uselist_tmp
fields terminated by ','
EOI
    ;
print "$query\n";
my $rows = $dbh->do($query);
print "$rows rows loaded into uselist.tmp\n";
$query = "drop table if exists rap_ops_uselist";
print "$query\n";
$dbh->do($query);
$query = "alter table uselist_tmp rename as rap_ops_uselist";
print "$query\n";
$dbh->do($query);
unlink($out_db_file) ||
    die "could not unlink $out_db_file: $!";
$dbh->disconnect();

# name the uselist file with the max_date_found
my $base_file = "${max_day_found}_meso_uselist.txt";
my $uselist_dir = "rap_ops_mesonet_uselists";
my $out_file = "$uselist_dir/$base_file";
print "out file is $out_file\n";
open(OUT,">$out_file") ||
    die "Cannot open $out_file for writing: $!";
  
print OUT qq{; First, we go through  table \'$stats_table\' and\n}.
    qq{; look for stations satisfying the following criteria for\n}.
    qq{; wind, temperature, and dewpoint separately (from table madis3.limits)\n};
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

foreach my $key (sort keys %good_count) {
    my $str = sprintf("%12.12s any good: %4d good W: %4d, good T: %4d, good Td: %4d, \n",
		      $key,$good_count{$key},$good_W{$key}, $good_T{$key},$good_Td{$key});
    print OUT "; $str"; 
}
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
    my $diff = 1;
    if($name1 ne $name2) {
	$diff = $name2 lt $name1 ? 1 : -1;
    } elsif($net1 ne $net2) {
	$diff = $net2 lt $net1? 1 : -1;
    } else {
	my $fdiff = $flag2 - $flag1;
	$diff = $fdiff > 0 ? 1 : -1;
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
    
