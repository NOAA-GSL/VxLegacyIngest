#!/usr/bin/perl
use strict;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $DEBUG=0;  # MAKE THIS NON-ZERO TO PRODUCE EXTRA DEBUG PRINTOUT

#get directory
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

#useful DEBUGGING info vvvvvvvvvvvvvv
if($DEBUG) {
    foreach my $key (sort keys(%ENV)) {
        print "$key: $ENV{$key}\n";
    }
    print "thisDir is $thisDir\n";
    print "basename is $basename\n";
    print "\n";
}
# end useful DEBUGGING info ^^^^^^^^^^^^^^^^^
# END PREAMBLE^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


my $file = $ARGV[0];
my $out_file = $ARGV[1];
my $grib_type = $ARGV[2];
my $rh_flag = $ARGV[3];

my %inventory;

my @var_list = qw(PRES DPT UGRD VGRD TMP RH);
if($rh_flag == 1) {
    @var_list = qw(PRES DPT UGRD VGRD TMP SPFH);
}
open(I,"/opt/wgrib2/bin/wgrib2 $file|") ||
    die "could not run wgrib2 on $file: $!";
while(<I>) {
    #print;
    chomp;
    if(/(PRES):surface:/) {
	$inventory{$1} = $_;
    } else {
	if($rh_flag == 0) {
	    if(/(DPT|TMP|RH):2 m above/) {
		$inventory{$1} = $_;
	    } elsif(/(UGRD|VGRD):10 m above/) {
		$inventory{$1} = $_;
	    }
	} elsif($rh_flag == 1) {
	    if(/(DPT|TMP|SPFH):2 m above/) {
		$inventory{$1} = $_;
	    } elsif(/(UGRD|VGRD):10 m above/) {
		$inventory{$1} = $_;
	    }
	}
    }
}
close I;

foreach my $var (@var_list) {
    print "$inventory{$var}\n";
}
