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

my %inventory;

my @var_list = qw(DPT TMP);
open(I,"wgrib2 $file|") ||
    die "could not run wgrib2 on $file: $!";
while(<I>) {
    print;
    chomp;
    if(/(DPT|TMP):2 m above/) {
	$inventory{$1} = $_;
    }
}
close I;

my $cmd = "wgrib2 -i -order we:sn -no_header -bin $out_file $file";
#$cmd = "$wgrib2";
print "command: $cmd\n";

open(D,"| $cmd") ||
    die "could not make wgrib2 dump file: $!";
foreach my $var (@var_list) {
    print D "$inventory{$var}\n";
    print "$inventory{$var}\n";
}
close D;    
