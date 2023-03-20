my %month_num = (Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6,
		 Jul => 7, Aug => 8, Sep => 9, Oct =>10, Nov =>11, Dec =>12);
use vars(%month_num);

sub my_timeout {
    print STDERR "timeout\n";
    die 1;
}

sub get_surface_file {
    my($time,$data_source,$DEBUG,$desired_fcst_len,$start) = @_;
    my @result = "";
    my @r;
    @result = eval <<'END';
    alarm(10);			# 10-sec time limit on getting filename
    @r = get_model_file2($time,$data_source,$DEBUG,$desired_fcst_len,$start);
    alarm(0);			# reset alarm
    @r;
END
    if($@) {			#check for an error on the eval
	print "Bad eval: $@\n";
	@result="";
    }
    #print "result is @result\n";
    return @result;
}

sub get_model_file2 {
    my($time,$data_source,$DEBUG,$desired_fcst_len,$start)=@_;
    my ($out_file,$type,$fcst_len);    
    my ($dym,$dym,$hour,$mday,$month,$year,$wday,$yday) = gmtime($time);
    my $jday=$yday+1;
    if($DEBUG) {
	print "|$start| year,month,jday,hour = $year, $month, $jday, $hour\n";
    }
    unless(defined $desired_fcst_len) {
	$desired_fcst_len = -1;
    }

# first look for an analysis (for ruc, anal and forecast are in same dir)
    my $anal_dir;
    if($data_source eq "Bak13") {
	$anal_dir = "/whome/rtruc/ruc_backup/ruc_presm/";
    }
    if ($DEBUG) {
	print "data source is $data_source.  looking\n";
	print "in directory $anal_dir\n";
    }
    my $anal_file;
    ($out_file,$type,$fcst_len) =
	get_best_file($anal_dir,$time,$DEBUG,$desired_fcst_len,$start);

    #if it is not available, try the backup
    if(! $out_file) {
	#no luck -- try the retro directory
	my $retro_dir = "private/retro_data";
	if($DEBUG) {print "Checking retro files\n";}
	($out_file,$type,$fcst_len)=get_best_file($retro_dir,$time,$DEBUG);
    }				# 
    return ($out_file,$type,$fcst_len);
}

sub get_best_file {
    my($fcst_dir,$time,$DEBUG,$desired_fcst_len,$start) = @_;
    #opendir has that problem again with perl!!!!!
    opendir(MAPSF, "$fcst_dir") ||
	print("trouble opening $fcst_dir: $!");
    my @fcst_files = reverse sort grep /^\d*(|.grib)$/, readdir(MAPSF);
    closedir(MAPSF);
    foreach my $file (@fcst_files) {
	#print "$file\n";
    }

    #find the file with the right valid time and the shortest forecast time
    # OR, if $desired_fcst_len is set, look for that one
    my $shortest_fcst = 9999;
    my $best_file="";
    my ($file,$out_file,$type,$fcst_len);
    require "jy2mdy.pl";		# to convert julian day
    use Time::Local;		# has timegm in it
    my $s1 = gmtime($time);
    if($DEBUG){print "looking for $s1\n";}
    foreach $file (@fcst_files) {
	$file =~ /(..)(...)(..)0000(..)/;
	my $year=$1;
	if($year < 80) {
	    $year +=2000;
	} else {
	    $year +=1900;
	}
	my $jday=$2;
	my $hour=$3;
	my $fcst_len=int $4;
	my $mon_name;
	use vars qw($jday,$year $mon $mday $hour);
	($dum,$mday,$mon_name,$year) = jy2mdy($jday,$year);
	my $mon = $month_num{$mon_name}-1;
	my $valid_time = timegm(0,0,$hour,$mday,$mon,$year) + 3600*$fcst_len;
	my $sss = gmtime($valid_time);
	#if($DEBUG){print "file $file, valid at $sss, fcst_len = $fcst_len\n";}
	if($time == $valid_time) {
	    if($desired_fcst_len >= 0) {
		# we want a particular forecast projection
		if($fcst_len == $desired_fcst_len) {
		    $shortest_fcst = $fcst_len;
		    $best_file = $file;
		    last;
		}
	    } else {
		# we want the shortest forecast projection
		if($fcst_len < $shortest_fcst) {
		    $shortest_fcst = $fcst_len;
		    $best_file = $file;
		}
	    }
	} else {
	    # we may be asking for the latest of a particular fcst proj
	    # regardless of the time
	    if($desired_fcst_len >= 0 && $start eq "latest") {
		if($fcst_len == $desired_fcst_len) {
		    $shortest_fcst = $fcst_len;
		    $best_file = $file;
		    last;
		}
	    }
	}
    }
    if($best_file) {
	if($DEBUG){print "Found: $best_file\n";}
	$out_file = "$fcst_dir/$best_file";
	$type="F";
        $fcst_len = int $shortest_fcst;
    } else {
	$out_file="";
	$type="Missing";
        $fcst_len="";
    }
    return($out_file,$type,$fcst_len);
}

1;    # return something so the require is happy
