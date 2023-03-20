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

my %HoH;			# a hash of hashes (see Programming Perl p 270)
my %vars_2d;
my $grid_lat;
my $grid_lon;
my ($var,$lev,$dum,$val);

my $arg = "/apps/wgrib2/0.1.9.6a/bin/wgrib2 $file| $thisDir/get_fields_in_order.pl |".
#grep 'HGT\\|TMP\\|RH\\|GRD' | grep 'mb:' |".
    "/apps/wgrib2/0.1.9.6a/bin/wgrib2 -i -order raw -no_header -bin $out_file $file >/dev/null 2>&1";
#print "$arg\n";
system($arg) &&
    die "2: could not execute $arg: $!";
