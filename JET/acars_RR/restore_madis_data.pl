#!/usr/bin/perl
use strict;

# for this to load retrospective, it must run suid moninger
# set user ID on execution (do this with 'chmod u+s')

my $DEBUG=1;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
#for security
$ENV{'PATH'}="";

$ENV{'TZ'}="GMT";

#redirect stderr to stdout so we can see err msgs on the web
#$|=1;  #force flush of buffers after each print
#open (STDERR, ">&STDOUT") || die "can't dup stdout ($!)\n";

#use lib "/w3/utilities"; # my utilities
#require "timelocal.pl";   #includes 'timegm' for calculations in gmt
use Time::Local;

#get directory and URL
use File::Basename;
my ($dum,$thisDir) = fileparse($ENV{SCRIPT_FILENAME} || '.');
$thisDir =~ m|([\-\~\.\w\/]*)|; # untaint
$thisDir = $1;
my ($basename,$thisURLDir) = fileparse($ENV{'SCRIPT_NAME'} || '.');
$basename =~ m|([\-\~\.\w]*)|;  # untaint
$basename = $1;
$thisURLDir =~ m|([\-\~\.\w\/]*)|;      # untaint
$thisURLDir = $1;

#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
# get full path
$thisDir = $ENV{PWD};

my $startTime = $ARGV[0];
my $endTime = $ARGV[1];
my $heraTransfer = $ARGV[2]; # flag to transfer data to hera (no - 0, yes - 1)
my $err_file = "err.out";

open (STDERR,">$err_file");
for(my $time = $startTime; $time < $endTime; $time += 3600) {
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) =
    gmtime($time);
    $year += 1900;
    my $atime = sprintf("%2.2d%3.3d%2.2d00",$year%100,$yday+1,$hour);

    my $output_file = "ACARS_RETRO_DIR/${atime}q.cdf";
    restore_madis_data($time,$err_file,$output_file,$DEBUG);
}

sub restore_madis_data {
    my($startTime,$err_file,$out_file,$DEBUG) = @_;
    my $arg;
    #if($DEBUG) {print "in restore_madis_data\n";}
    $ENV{FTP_PASSIVE} = 1;	# ensure passive mode for firewall issues
    my($sec,$min,$hour,$start_mday,$start_mon,$start_year,
       $wday,$yday,$isdst) = 	gmtime($startTime);
    $start_mon++;		# make Jan = 1, not 0
    $start_year += 1900;
    my $archive_dir =
	sprintf("/archive/%4d/%02d/%02d/point/acars/netcdf",
		$start_year,$start_mon,$start_mday);
    my $archive_file =
	sprintf("%4d%02d%02d_%02d00.gz",
		$start_year,$start_mon,$start_mday,$hour);
    use Net::FTP;
    my @hosts = qw(madis-data.ncep.noaa.gov madis-data.cprk.ncep.noaa.gov);
    my $done=0;
    foreach my $host (@hosts) {
	my $ftp = Net::FTP->new($host,Timeout=>60) ||
	    print "cannot connect to $host: $!";
	unless($ftp) {
	    next;
	}
	unless($ftp->login("anonymous","aircraft_request.GSD\@noaa.gov")) {
	    print "login failed: $!";
	    $ftp->quit();
	    next;
	}
	if($DEBUG) {print "logged in to $host\n";}
	my $old_type = $ftp->binary();
	#print STDERR "old_type was $old_type\n";
	unless($ftp->cwd($archive_dir)) {
	    print "couldn't cwd to $archive_dir: $!";
	    $ftp->quit();
	    next;
	}
	if($DEBUG) {
	    print "got to $archive_dir\n";
	    my @files = $ftp->dir;
	    #print "files are @files\n";
	}
	my $local_file = "ACARS_RETRO_DIR/$archive_file";
	unless($ftp->get($archive_file,$local_file)) {
	    print "couldn't get $archive_file from $host into $local_file\n".
		"from $archive_dir on $host: $!";
	    $ftp->quit();
	    next;
	}
	if(-s $local_file > 100000) {
	    chmod 0777, $local_file;
	    if($DEBUG) {
		print "got $archive_file from $host\n";
		print "local file is $local_file\n";
	    }
	    # now gunzip
	    $arg = "/bin/gunzip -f $local_file";
            print "unzipping file ($arg)\n";
	    if(system($arg)) {
		if($DEBUG) {
		    print "problem unzipping ($arg): $!";
		}
	    }
	    $local_file =~ s/\.gz$//;
	    rename($local_file,$out_file);
	    chmod 0777, $out_file;
            my ($retrofile,$dumDir) = fileparse($out_file || '.');
            # See if we should transfer to Hera
            if($heraTransfer == 1) {
              #$arg = "/bin/rsync -auv $out_file amb-verif\@dtn-hera.fairmont.rdhpcs.noaa.gov:/scratch1/BMC/amb-verif/acars_retro_data/";
              $arg = "/bin/scp /lfs1/BMC/amb-verif/acars_retro_data/$retrofile amb-verif\@dtn-hera.fairmont.rdhpcs.noaa.gov:/scratch1/BMC/amb-verif/acars_retro_data/";
              if(system($arg)) {
                if($DEBUG) {
                    print "problem transfering to Hera ($arg): $!\n";
                }
              }
            } else {
              print "Not transfering to Hera.\n";
            }
	    last;
	} else {
	    print "file size too small for $local_file\n";
	    $ftp->quit();
	    next;
	}
    }
}

1;  # return something so the 'require' is happy
