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
my $var;
my $lev;

open(I,"/apps/wgrib2/0.1.9.6a/bin/wgrib2 -set center 7 $file|") ||
    die "could not run wgrib2 on $file: $!";
while(<I>) {
    #print;
    chomp;
    $var="";
    $lev="";
    if(/(HGT):(surface)/) {
	$var = $1;
	$lev = 0;
    } elsif(/(HGT):(cloud base)/) {
	$var = $1;
	$lev = 1;
    }
    # all this efforts because fields apparently appear twice in the analysis
    # files.  This takes the first appearence of each field/level combination
    # (at least this happened for GFS data, maybe not in Op20)
    unless($HoH{$var}{$lev}) {
	#print;
	$HoH{$var}{$lev} = $_;
    }
}
close I;

open(D,"|/apps/wgrib2/0.1.9.6a/bin/wgrib2 -set center 7 -i -order raw -no_header -bin $out_file $file >/dev/null 2>&1") ||
    die "could not make wgrib2 dump file: $!";
my @var_list = qw(HGT CEIL);
foreach my $var (@var_list) {
    foreach my $lev (sort {$a - $b} keys %{$HoH{$var}}) {
	my $val_out = $HoH{$var}{$lev};
	print D "$HoH{$var}{$lev}\n";
	print "$HoH{$var}{$lev}\n";
    }
}
close D;
