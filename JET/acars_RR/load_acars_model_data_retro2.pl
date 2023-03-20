#!/usr/bin/perl
#PBS -d .                                                                                                                 
#PBS -N AMDR_MDL_loader
#PBS -A amb-verif                                                                                                             
#PBS -l procs=1                                                                                                           
#PBS -l partition=tjet:ujet:sjet:vjet:xjet                                                                                                    
#PBS -q service                                                                                                           
#PBS -l walltime=01:00:00                                                                                                 
#PBS -l vmem=1G                                                                                                           
#PBS -M verif-amb.gsd@noaa.gov                                                                                            
#PBS -m a                                                                                                                 
#PBS -e tmp2/                                                                                                              
#PBS -o tmp2/ 
#

#
use strict;
use POSIX qw(strftime);

my $thisDir = $ENV{PBS_O_WORKDIR};
unless($thisDir) {
    # we've been called locally instead of qsubbed
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}
use Cwd 'chdir'; #use perl version so this isn't unix-dependentx
chdir ("$thisDir") ||
          die "xsCan't cd to $thisDir: $!\n";
require "./load_summaries_retro2.pl";
#require "./update_bad_tails.pl";

# see if this job is still running from a previous invocataion
open(P,"/bin/ps guxww|") ||
    die ("cannot run ps: $!");
my $this_pid = $$;
#print "this pid is $this_pid\n";
while (<P>) {
    my @items = split(/\s+/,$_);
    my $pid = $items[1]+0;
    #print;
    if($pid == $this_pid) {
        next;
    }
    if(m|$0\s*$ARGV[0]| &&
        !m|emacs|) {
        print "ANOTHER INVOCATION!: $_";
        my $time_str = gmtime(time());
        print "killing myself on $time_str\n";
        exit(1);
    }
}

$ENV{PATH} = "$ENV{PATH}:/usr/lib64/perl5/";

my $DEBUG=1;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT


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

use DBI;
#set database connection parameters
$ENV{DBI_DSN} = "DBI:mysql:acars_RR2:wolphin.fsl.noaa.gov;mysql_local_infile=1";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1, PrintWarn => 1});
  
# search for written but not loaded data files
my $tmp_dir = "tmp2";
opendir(DIR,$tmp_dir) ||
    die "cannot open $tmp_dir: $!\n";
my @allfiles = grep /written_retro$/,readdir DIR;
foreach my $basefile (@allfiles) {
    my $file = "$tmp_dir/$basefile";
    print "file is $file\n";
    if(-s $file > 0) {
	my($model,$atime,$fcst_len) = split(/\./,$basefile);
	print "model is $model\n";
        # create retro tables in teh database unless they already exist
        my $output = `./make_retro_tables2.pl $model`;
        print $output; 
	load_model_data($model,$file,$fcst_len,$dbh,\%id,\%mdcrs_id,\%airline);
    } else {
	print "\nSKIPPING $file OF SIZE ZERO\n";
    }
}
closedir DIR;

sub load_model_data {
    use strict;
    my ($model,$file,$fcst_len,$dbh,$id_ptr,$mdcrs_id_ptr,$airline_ptr) = @_;
    my %id = %$id_ptr;
    my %mdcrs_id = %$mdcrs_id_ptr;
    my %airline = %$airline_ptr;
    my %db_id;			# hash to hold id for each tn
    my %min_time;			# holds min date seen for each tn
    my %max_time;			# guess
    my %ac_type;			# aircraft ac_type
    my %cb_T;				# current_bad_T for each tail
    my %cb_W;				# current_bad_W for each tail
    my %cb_RH;				# current_bad_RH for each tail
    my %n_obs;			# obs for each tail
    my $query;
    my $sth;
    my $rows;

    # try this to turn some mysql warnings into errors (but it doesn't seem to work)
    #$dbh->do(qq{set sql_mode='traditional'});

    # here's where we should go through the tmp_table and add a yes-no on whether the lat/lon is in the HRRR domain
# we'll use w3fb11.pl in this directory.
    require "./w3fb11.pl";
    
# add the in_HRRR flag to the input
    # HRRR projection
    my $alat1 = 21.138;
    my $elon1 = 237.28;
    my $dx = 3000;
    my $elonv =262.5;
    my $alatan = 38.5;
    my $nx = 1799;
    my $ny = 1059;
    
    my $out_file = "$file.$$.w_HRRR";
    print "file is $file, out file is $out_file\n";
    open(IN,$file) ||
	die "could not open $file: $!";
    open(OUT,">$out_file") ||
	die "could not open $out_file for writing: $!";
    while(<IN>) {
	my $line = $_;
	chomp $line;
	my @stuff = split(/\,/,$line);
	my $lat = $stuff[3]/100;
	my $lon = $stuff[4]/100;
	my($xi,$yj) = w3fb11($lat,$lon,$alat1,$elon1,$dx,$elonv,$alatan);
	#print "$lat/$lon -> $xi/$yj\n";
	my $in_HRRR = 0;
	if($xi > 0 && $xi <= $nx &&
	   $yj > 0 && $yj <= $ny) {
	    $in_HRRR = 1;
	}
	#print "in_HRRR = $in_HRRR\n";
	print OUT "$line,$in_HRRR\n";
    }
    close(IN);
    close(OUT);

 # get database id for each tailnumber
$query =<<"EOI";
select xid,tailnum,n_obs,
       UNIX_TIMESTAMP(earliest),UNIX_TIMESTAMP(latest),
       airline,model,current_bad_T,current_bad_W,current_bad_RH
    from tail
    where n_obs > 0
EOI
    ;
$sth = $dbh->prepare($query);
my ($db_id,$tailnum,$n_obs,$min_time,$max_time,$airline,$ac_type,$cb_T,$cb_W,$cb_RH);
my $max_db_id = -1;
$sth->execute();
$sth->bind_columns(\$db_id,\$tailnum,\$n_obs,\$min_time,\$max_time,
		   \$airline,\$ac_type,\$cb_T,\$cb_W,\$cb_RH);
while($sth->fetch()) {
    #print "$id $tailnum $n_obs $min_time $max_time\n";
    $db_id{$tailnum} = $db_id;
#    if($db_id{$tailnum} != $id{$tailnum}) {
#	print STDERR "ERROR!  db ID ($id{$tailnum}) != XTAIL ($id{$tailnum}) ".
#	    "for $tailnum.\nUsing XTAIL value\n";
 #   }
    my $id = $id{$tailnum};
    if($id > $max_db_id) {
	$max_db_id = $id;
    }
    $min_time{$tailnum} = $min_time;
    $max_time{$tailnum} = $max_time;
    $n_obs{$tailnum} = $n_obs;
    $cb_T{$tailnum} = $cb_T;
    $cb_W{$tailnum} = $cb_W;
    $cb_RH{$tailnum} = $cb_RH;
    # see if we already know the airline for this tail
    if(defined $airline{$tailnum}) {
	if(defined $airline) {
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
	$ac_type{$tailnum} = $ac_type;
    }
}   
    
    my $pid = $$;
    my $tmp_table = "${model}_${pid}_tmp";
    my $obs_table = "acars_retro";
    $query=<<"EOI"
CREATE TEMPORARY TABLE $tmp_table (
  time int NOT NULL DEFAULT '0',
  fcst_len int DEFAULT NULL,
  tailnum varchar(9) NOT NULL DEFAULT '',
  lat smallint(6) NOT NULL DEFAULT '0',
  lon smallint(6) NOT NULL DEFAULT '0',
  press smallint(6) NOT NULL DEFAULT '0',
  t mediumint(9) DEFAULT NULL,
  dir smallint(5) unsigned DEFAULT NULL,
  s mediumint(9) DEFAULT NULL,
  hdg smallint(5) unsigned DEFAULT NULL,
  ul mediumint(9) DEFAULT NULL,
  vx mediumint(9) DEFAULT NULL,
  mach smallint(6) DEFAULT NULL,
  rh tinyint(3) unsigned DEFAULT NULL,
  ht smallint(6) DEFAULT NULL,
  ap_id smallint(5) unsigned DEFAULT NULL,
  up_dn tinyint(4) DEFAULT NULL,
  tf mediumint(9) DEFAULT NULL,
  dirf smallint(5) unsigned DEFAULT NULL,
  sf mediumint(9) DEFAULT NULL,
  ulf mediumint(9) DEFAULT NULL,
  vxf mediumint(9) DEFAULT NULL,
  vdiff mediumint(9) DEFAULT NULL,
  rhf tinyint(3) unsigned DEFAULT NULL,
  htf smallint(6) DEFAULT NULL,
  in_HRRR tinyint unsigned default null comment '1 if this ob is in the HRRR domain')
EOI
;
    print "$query\n";
    $dbh->do($query);
    print_warn($dbh);
    
    $query=<<"EOI"
load data concurrent local infile '$out_file' 
into table $tmp_table columns terminated by ','
(time,fcst_len,tailnum,lat,lon,press,t,dir,s,hdg,ul,vx,mach,rh,ht,ap_id,
up_dn,tf,dirf,sf,ulf,vxf,vdiff,rhf,htf,in_HRRR)
EOI
    ;

print "$query";
$rows = $dbh->do($query);
print_warn($dbh);

print "$rows rows affected\n\n";


#update entries needed for tail
my $tail_update_needed = 0;
$query=<<"EOI"
select tailnum,max(time),count(tailnum)
from $tmp_table
group by tailnum
EOI
    ;
print "$query";
$sth = $dbh->prepare($query);
my($tail,$time,$count);
$sth->execute();
$sth->bind_columns(\$tail,\$time,\$count);
while($sth->fetch()) {
    if(!defined $max_time{$tail}) {
	$tail_update_needed = 0;
	print "first time we've seen $tail. Ignoring it!! (bad idea)\n\n";
    }
    #print "$tail, $max_time{$tail}, $time\n";
    if($max_time{$tail} < $time) {
	# we're seeing new obs for this tail
	$tail_update_needed = 1;
	$max_time{$tail} = $time;
	$n_obs{$tail} += $count;
    }
}
$sth->finish();

#update tail table
if($tail_update_needed) {
    my $load_tail_file = "tmp/$$.load_tail.tmp";
    open(LTF,">$load_tail_file") ||
	die "couldn't open $load_tail_file: $!";
    foreach my $tail (sort keys %id) {
	my $min_date = sql_date($min_time{$tail});
	my $max_date = sql_date($max_time{$tail});
	if($n_obs{$tail} > 0) {
	    print(LTF "$id{$tail},$tail,$n_obs{$tail},$min_date,$max_date,".
		  code_nulls($airline{$tail}).",".code_nulls($ac_type{$tail}).",".
		  code_nulls($mdcrs_id{$tail}).",".
		  code_nulls($cb_T{$tail}).",".code_nulls($cb_W{$tail}).",".code_nulls($cb_RH{$tail})."\n");
	}
    }
    close(LTF);
     $query=<<"EOI"
load data concurrent local infile '$load_tail_file' 
replace into table tail columns terminated by ','
(xid,tailnum,n_obs,earliest,latest,airline,model,mdcrs_id,current_bad_T,current_bad_W,current_bad_RH)
EOI
    ;
print "$query";
$rows = $dbh->do($query);
print_warn($dbh);
print "$rows rows affected\n\n";
# unlink the file
unlink $load_tail_file ||
    die "could not unlink $load_tail_file: $!"
} else {
    print "no need to update tail\n\n";
}

# store new acars obs into table acars_retro
$query=<<"EOI"
insert ignore into $obs_table
(date,xid,lat,lon,press,t,dir,s,hdg,ul,vx,mach,rh,ht,ap_id,up_dn,source)
select from_unixtime(t.time),xid,lat,lon,press,t,dir,s,hdg,ul,vx,mach,rh,ht,ap_id,up_dn,in_HRRR
from $tmp_table as t,tail
where t.tailnum = tail.tailnum
EOI
;
print "$query";
$rows = $dbh->do($query);
print_warn($dbh);
print "$rows rows affected\n\n";

# now that we have new aid's for the new acars obs, store them in the model table
my $table = "${model}";
$query=<<"EOI"
replace into $table
(aid,time,fcst_len,tf,dirf,sf,ulf,vxf,vdiff,rhf,htf)
# describe
select o.aid
,date(from_unixtime(t.time)) as time,t.fcst_len
,t.tf,t.dirf,t.sf,t.ulf,t.vxf,t.vdiff,t.rhf,t.htf
from $obs_table as o ,$tmp_table as t,tail
where 1=1
and o.date = from_unixtime(t.time)
and o.xid = tail.xid
and tail.tailnum = t.tailnum
and o.lat = t.lat
and o.lon = t.lon
and o.press = t.press
EOI
    ;
print "$query";
$rows = $dbh->do($query);
print_warn($dbh);
print "$rows rows affected\n\n";

# update the sums
$query = "select min(time),max(time) from $tmp_table";
my($min_time,$max_time) = $dbh->selectrow_array($query);
my $min_date = sql_date($min_time);
my $max_date = sql_date($max_time);
# but first get the bad T, W, RH values for the time in question
# this table contains ONLY tails that have at least one variable (T, W, or R) bad.
$query=<<"EOI"
create temporary  table retro_rejects (
    tailnum varchar(9) not null comment 'actual tailnumber',
    bad_T enum('T'),
    bad_W enum('W'),
    bad_RH enum('R'),
    xid smallint unsigned primary key
    )
EOI
    ;
print "$query\n";
$dbh->do($query);
# get tail reject file
my $basefile = strftime("%Y%m%d_rejects.txt",gmtime($min_time));
my $reject_file = "amdar_reject_lists/$basefile";
print "reject file is $reject_file\n";
my $reject_tmp_file = "tmp/$$.reject_file.tmp";
my $arg = "sed 's/\  \\+/\ /g' $reject_file > $reject_tmp_file";
print "$arg\n";
system($arg);
$query=<<"EOI"
load data local infile '$reject_tmp_file'
replace into table retro_rejects
fields terminated by ' '
lines terminated by '\n'
ignore 16 lines
(tailnum,bad_T,bad_W,bad_RH,xid)
EOI
    ;
print "$query\n";
my $rows = $dbh->do($query);
#print_warn($dbh);
print "$rows rows inserted into retro_rejects table\n";
   
#update_bad_tails($dbh); # this is done in make_7day_stats.pl now.
load_summaries_retro2($dbh,$model,$fcst_len,$min_date,$max_date,0);
load_summaries_retro2($dbh,$model,$fcst_len,$min_date,$max_date,-1);
load_summaries_retro2($dbh,$model,$fcst_len,$min_date,$max_date,1);
load_summaries_retro2($dbh,$model,$fcst_len,$min_date,$max_date,2);

$query = "drop table retro_rejects";
$dbh->do($query);
unlink($reject_tmp_file) ||
    die "could not unlink $reject_tmp_file: $!";

$query = "drop table $tmp_table";
print "$query\n";
$dbh->do($query);

my $loaded_file = $file;
$loaded_file =~ s/written_retro$/loaded_retro/;
rename($file,$loaded_file) ||
    die "could not rename $file: $!";
unlink($out_file) ||
    die "could not unlink $out_file: $!";
}
	
sub sql_date {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
		   $year,$mon,$mday,$hour,$min,$sec);
}
 
sub code_nulls {
    my $val = shift;
    my $result = '\\N';
    if(defined $val) {
	$result = $val;
    }
    return $result;
}

sub print_warn {
    my $dbh = shift;
    my $warnings = $dbh->selectall_arrayref('SHOW WARNINGS');
    for my $row (@$warnings) {
	print "@{$row}\n";
    }
}
