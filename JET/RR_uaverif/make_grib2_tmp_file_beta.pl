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
my $i_grid = $ARGV[3];
my $j_grid = $ARGV[4];
my $nz = $ARGV[5];

my %HoH;			# a hash of hashes (see Programming Perl p 270)
my $var;
my $lev;

my $re = qr/(PRES|HGT|TMP|SPFH|UGRD|VGRD)/;
if($hydro == 1) {
    $re = qr/(PRES|HGT|TMP|SPFH|UGRD|VGRD|CLWMR|CICE|RWMR|SNMR|GRLE)/;
}
open(I,"/apps/wgrib2/0.1.9.6a/bin/wgrib2 $file|") ||
    die "could not run wgrib2 on $file: $!";
while(<I>) {
    #print;
    chomp;
    $var="";
    $lev=0;
    if(/$re:(.*) (hybrid level|sigma)/) {
	$var = $1;
	$lev = sprintf("%f",$2);
        #print;
   } elsif(/(CAPE):255-0 mb above ground:/) {
	$var = $1;
	$lev = 255;
        #print;
    } elsif(/(CIN):255-0 mb above ground:/) {
	$var = $1;
	$lev = 255;
        #print;
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

open(D,"|/apps/wgrib2/0.1.9.6a/bin/wgrib2 -ij $i_grid $j_grid -i -order raw -no_header -bin $out_file $file >/dev/null 2>&1") ||
    die "could not make wgrib2 dump file: $!";
my @var_list = qw(PRES HGT TMP SPFH UGRD VGRD CAPE CIN);
if($hydro == 1) {
    #CLWMR|CICE|RWMR|SNMR|GRLE))/;
    @var_list = qw(PRES HGT TMP SPFH UGRD VGRD CLWMR RWMR SNMR CICE GRLE CAPE CIN);
}

my $i_var = 0;
print "\nMAKE SURE THE FIELDS BELOW ARE THE ONES YOU EXPECT, AND IN THE ORDER YOU EXPECT!!!!\n\n";
foreach my $var (@var_list) {
    if(defined $HoH{$var}) {
	$i_var++;
    }
    my $i_lev=0;
    foreach my $lev (sort {$a <=> $b} keys %{$HoH{$var}}) {
	my $val_out = $HoH{$var}{$lev};
	if($i_lev++ < $nz) {
	    print D "$HoH{$var}{$lev}\n";
	    print "$i_var, $var: $lev: $HoH{$var}{$lev}\n";
	} else {
	    print  "IGNORED: $i_var, $var: $lev: $HoH{$var}{$lev}\n";
	}
    }
}
close D;
