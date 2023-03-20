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
my $hydro = $ARGV[2];
my $nz = $ARGV[3];

my %HoH;			# a hash of hashes (see Programming Perl p 270)
my $var;
my $lev;

my $re = qr/((HGT|TMP|RH|UGRD|VGRD))/;
if($hydro == 1) {
    $re = qr/((HGT|TMP|RH|UGRD|VGRD|CLWMR|CICE|CIMIXR|ICMR|RWMR|SNMR|GRLE))/;
}

open(I,"/apps/wgrib2/0.1.9.6a/bin/wgrib2 $file|") ||
    die "could not run wgrib2 on $file: $!";
while(<I>) {
    #print;
    chomp;
    $var="";
    $lev="";
#    if(/((PRES|HGT|TMP|RH|UGRD|VGRD)):(\d+) (hybrid|mb)/) {
    if(/$re:(\d+) mb/) {
        #print;
        #print "\n";
	$var = $1;
	$lev = $3;
   } elsif(/(CAPE):255-0 mb above ground:/) {
	$var = $1;
	$lev = 255;
    } elsif(/(CIN):255-0 mb above ground:/) {
	$var = $1;
	$lev = 255;
    }
    # all this efforts because fields apparently appear twice in the analysis
    # files.  This takes the first appearence of each field/level combination
    # (at least this happened for GFS data, maybe not in Op20)
    unless($HoH{$var}{$lev}) {
#	print;
	$HoH{$var}{$lev} = $_;
    }
}
close I;

#print "\n";
open(D,"|/apps/wgrib2/0.1.9.6a/bin/wgrib2 -i -order raw -no_header -bin $out_file $file >/dev/null 2>&1") ||
    die "could not make wgrib2 dump file: $!";
my @var_list = qw(HGT TMP RH UGRD VGRD CAPE CIN);
if($hydro == 1) {
    #CLWMR|CICE|RWMR|SNMR|GRLE))/;
    # need ICMR for the HI_iso fields, apparently
    @var_list = qw(HGT TMP RH UGRD VGRD CLWMR RWMR SNMR CICE CIMIXR ICMR GRLE CAPE CIN);
}
my $i_var = 0;
print "\nMAKE SURE THE FIELDS BELOW ARE THE ONES YOU EXPECT, AND IN THE ORDER YOU EXPECT!!!!\n\n";
foreach my $var (@var_list) {
    if(defined $HoH{$var}) {
	$i_var++;
    }
    my $i_lev=0;
    foreach my $lev (sort {$b - $a} keys %{$HoH{$var}}) {
	my $val_out = $HoH{$var}{$lev};
	if($lev <= 1000) {
	    # a hack to eliminate the annoying 1013 mb level in HRRR iso files
	    # don't allow more levels than we are expecting. This is needed because for some files
	    # hydrometeor variables don't go as high as mass and temperature variables
	    # (like RAP_OPS_iso_242)
	    if($i_lev++ < $nz) {
		print D "$HoH{$var}{$lev}\n";
		#print  "$i_var, $var: $lev: $HoH{$var}{$lev}\n";
	    } else {
		#print  "IGNORED: $i_var, $var: $lev: $HoH{$var}{$lev}\n";
	    }
	}
    }
}
close D;
