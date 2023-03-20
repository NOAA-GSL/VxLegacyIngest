#!/usr/bin/perl
#SBATCH -J precip_1min_make
#SBATCH --mail-user=verif-amb.gsl@noaa.gov                                                                                          
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service 
#SBATCH -t 01:00:00
#SBATCH --mem=1G
#SBATCH -D .
#SBATCH -e /home/amb-verif/precip_1min/tmp/precip_1min_make.e%j
#SBATCH -o /home/amb-verif/precip_1min/tmp/precip_1min_make.o%j
#
#
use strict;
use POSIX;
my $thisDir = $ENV{SLURM_SUBMIT_DIR};
unless($thisDir) {
    # we've been called locally instead of qsubbed
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $DEBUG=0;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT


#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
$thisDir = $ENV{PWD};

#useful DEBUGGING info vvvvvvvvvvvvvv
if($DEBUG) {
    foreach my $key (sort keys(%ENV)) {
    	print "$key: $ENV{$key}\n";
    }
    print "thisDir is $thisDir\n";
    print "\n";
}
# end useful DEBUGGING info ^^^^^^^^^^^^^^^^^
# END PREAMBLE^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

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
    if(-M $file > 1) {
        print "unlinking $file\n";
        unlink "$file" || print "Can't unlink $file $!\n";
    }
}
closedir DIR;

use DBI;

my $data_file = "tmp/precip_1min.obs.$$.written";
open(DF,">$data_file") ||
    die "could not open $data_file: $!";

my @all_minutes = (1..60);

my $hrs_ago = abs($ARGV[0]) || 0;
my $endSecs = time() - $hrs_ago*3600;
# put on an hour boundary
$endSecs -= $endSecs%3600;

#connect
$ENV{DBI_DSN} = "DBI:mysql:precip_1min:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";
my $sth;

$query=<<"EOI"
select name,o.sta_id,time
,precip,wx,cvr
from 1min_asos.sky sky,1min_asos.stations s
    ,1min_asos.obs o left join 1min_asos.present p on p.id = o.wx_id
where 1=1
and o.sky_id = sky.id
and s.id = o.sta_id		# a.b (emacs coloration)
and time >   $endSecs - 3600-1800
and time <=   $endSecs + 10*60
# and time >  1523750400 -3600-1800
# and time <=   1523750400+ 10*60
#and name = 'kart'
order by name,time
EOI
;
$sth = $dbh->prepare($query);
$sth->execute();
my($name,$sta_id,$time,$precip,$wx,$cvr);
$sth->bind_columns(\$name,\$sta_id,\$time,\$precip,\$wx,\$cvr);
my $name_last = "";
my $precip_last = -1;
my $hr_last = -1;
my $start_precip;
my $tot_precip=0;
my $top_precip = 0;
my $n_in_hr=0;
my $n_hours_for_station=0;
my $accum_precip=0;
my $accum_precip_last=0;
my %missing_minutes;
my @reset_minutes;
my %precip_in_minute;
my $INCOMPLETE=0;
my $tot_estimated_error=0;
while($sth->fetch()) {
    my $time_str1 = gmtime($time);
    my $this_minute = floor(($time%3600)/60);
    if($this_minute == 0) {
	$this_minute = 60;
    }
    my $hour = ceil($time/3600);

    if($name ne $name_last) {
	#print "a new station: $name\n";
	$name_last = $name;
	$precip_last = 0;
	$hr_last = -1;
	$n_hours_for_station=0;		# counts hours for this station. First hour will be partial
	$start_precip=0;
	$tot_precip = 0;
	$accum_precip=0;	# holds cumulative precip over all hours for this station.
	@reset_minutes=();
	undef %precip_in_minute;
    }
    $name_last = $name;
	
    if($hour > $hr_last) {
	#print "STARTING NEW HOUR\n";
	# a new hour. Put out data for previous hour, if it's available
	if($n_hours_for_station++ > 1) {
	    #print "PUTTING OUT PREVIOUS HOUR\n";
	    # we have a (full) previous hour to process
	    my $time_str = gmtime(3600*$hr_last);
	    $tot_precip = $accum_precip_last - $start_precip;
	    my $missing_minutes="";
	    foreach my $minute (sort {$a - $b} keys %missing_minutes) {
		$missing_minutes .= "$minute ";
	    }
	    if($missing_minutes eq "") {
		$missing_minutes = "\\N";
	    }
	    # put out data for last hour
	    # QC: mark the total as bad if the 5 minutes before any reset_minute are missing
	    if(@reset_minutes > 0 && %missing_minutes) {
		for(my $i=0;$i<@reset_minutes;$i++) {
		    my $reset_minute = $reset_minutes[$i];
		    my $needed_minute = $reset_minute - 1;
		    if(defined $missing_minutes{$needed_minute}) {
			# estimate error by looking further back
			my $found=0;
			#print "checking previous minute\n";
			for(my $minutes_ago=1;$minutes_ago<=5;$minutes_ago++) {
			    if(defined $precip_in_minute{$needed_minute-$minutes_ago}) {
				print "station $name: found inc precip $precip_in_minute{$needed_minute-$minutes_ago} ".
				    " for minute $needed_minute-$minutes_ago\n";
				$found=1;
				if($tot_estimated_error < 65535) {
				    $tot_estimated_error += $precip_in_minute{$needed_minute-$minutes_ago};
				}
				last;
			    }
			}
			if(!$found) {
			    print "$name, $time_str can't estimate error for minute $reset_minute\n";
			    $tot_estimated_error = 65535; # max_unsigned smallint
			}
		    }
		}
	    }
	    if(%missing_minutes) {
		$INCOMPLETE=1;
	    }
	    my $valid_time = 3600*$hr_last;
	    my $reset_minutes = "\\N";
	    if(@reset_minutes) {
		$reset_minutes = join(" ",@reset_minutes);
	    }
	    if($tot_precip > 0) {
		print "hourly total for $name $time_str: tot: $tot_precip. err: $tot_estimated_error  times: $n_in_hr, reset min: $reset_minutes, ".
		    "missing: $missing_minutes\n";
	    }
	    print  DF "$sta_id,$valid_time,$tot_precip,$INCOMPLETE,$tot_estimated_error,$reset_minutes,$missing_minutes\n";
	} # end if($last_hour > 0)
	# into the new hour. Reset
	#print "RESETTING FOR NEW HOUR\n";
	$INCOMPLETE=0;
	@missing_minutes{@all_minutes} = map(1,@all_minutes); # reset %missing_minutes to include all minutes
	$start_precip = $accum_precip_last;
	$tot_precip = 0;
	$n_in_hr=0;
	@reset_minutes = ();
	$tot_estimated_error=0;
	# plug last 5 minutes of previous hour into precip in minute so the next hour has some history
	my %precip_last_hour;
	for(my $i=60;$i>54;$i--) {
	    $precip_last_hour{$i} = $precip_in_minute{$i};
	}
 	undef %precip_in_minute;
	for(my $i=60;$i>54;$i--) {
	    if(defined $precip_last_hour{$i}) {
		$precip_in_minute{$i-60} = $precip_last_hour{$i};
	    }
	}
   } # end if($hour > $last_hour)
    # accumulate
    #print "$name $time_str1 $this_minute $precip\n";
    if($precip > 0) {
	#print "$name $time_str1, $precip\n";
    }
    $accum_precip_last= $accum_precip;
    my $delta_precip = $precip - $precip_last;
    if($delta_precip < 0) {
	push(@reset_minutes,$this_minute);
	$accum_precip += $precip;
	$precip_in_minute{$this_minute} = $precip;
    } else {
	# some QC: eliminate obs with delta_precip > 0 but no wx
	if($delta_precip > 0 && !defined $wx && $cvr =~ /CLR/) {
	    print "ERROR? for station $name $time_str1: precip $delta_precip/$precip, but no wx. cvr = $cvr. not included in total\n";
	} else {
	    $accum_precip += $delta_precip;
	    $precip_in_minute{$this_minute} = $delta_precip;
	}
    }
    #print "accum_precip: $accum_precip\n";
    $precip_last = $precip;
    
    $hr_last = $hour;
    $n_in_hr++;
    delete $missing_minutes{$this_minute};
}
close DF;
$query =<<"EOI"
load data concurrent local infile '$data_file'
replace into table obs columns terminated by ','
(sta_id,valid_time,precip,incomplete,tot_estimated_error,reset_minutes,missing_minutes)
EOI
    ;
print "$query;\n";
$dbh->do($query);
 my $warnings = $dbh->selectall_arrayref('SHOW WARNINGS');
for my $row (@$warnings) {
    foreach my $item (@$row) {
	print "$item: ";
    }
    print "\n";
}
my $new_file = $data_file;
$new_file =~ s/.written/.loaded/;
rename($data_file,$new_file);



 
