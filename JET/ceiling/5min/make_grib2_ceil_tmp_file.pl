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
my $total_min = $ARGV[3];

my %HoH;			# a hash of hashes (see Programming Perl p 270)
my $var;
my $lev;
my $min_string;
my $ceiling_as_height = 0;

open(I,"/apps/wgrib2/0.1.9.6a/bin/wgrib2 -set center 7 $file|") ||
    die "could not run wgrib2 on $file: $!";
# finding the right minute
if($total_min == 0) {
    $min_string = "anl";
} else {
    $min_string = "$total_min min fcst";
}
while(<I>) {
    #print;
    chomp;
    $var="";
    $lev="";
    if(/(HGT):(surface):/) {	# don't need to match time, cuz this is a static field.
	$var = $1;
	$lev = 0;
    } elsif(/(HGT):(cloud ceiling):($min_string)/) {
	$ceiling_as_height=1;
	$var = $1;
	$lev = 1;
    } elsif(/(CEIL):(cloud ceiling):($min_string)/) {
	$ceiling_as_height=0;
	$var = $1;
	$lev = 1;
    }
    unless($HoH{$var}{$lev}) {
	$HoH{$var}{$lev} = $_;
    }
}
close I;

open(D,"|/apps/wgrib2/0.1.9.6a/bin/wgrib2 -set center 7 -i -order raw -no_header -bin $out_file $file >/dev/null 2>&1") ||
    die "could not make wgrib2 dump file: $!";
my @var_list = qw(HGT);
if($ceiling_as_height == 0) {
    @var_list = qw(CEIL);
}
foreach my $var (@var_list) {
    foreach my $lev (sort {$a - $b} keys %{$HoH{$var}}) {
	my $val_out = $HoH{$var}{$lev};
	print D "$HoH{$var}{$lev}\n";
	print "$HoH{$var}{$lev}\n";
    }
}
close D;
