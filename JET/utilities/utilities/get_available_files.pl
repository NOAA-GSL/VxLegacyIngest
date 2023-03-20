#!/usr/bin/perl
#
# gets a list of model files that are available on jet for
# use by the grid viewer
#
use strict;
my $DEBUG=1;
use Time::Local;
use Time::HiRes "usleep";
use DBI;
# set connection parameters for this directory
$ENV{DBI_USER} = "moninger";
$ENV{DBI_PASS} = "wpassw";
$ENV{DBI_DSN} = "DBI:mysql:files_on_jet:wolphin.fsl.noaa.gov";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query=<<"EOI";
replace into files_on_jet.files
(one,time_checked,files)
values('1',?,?)
EOI
    ;
my $sth_replace = $dbh->prepare($query);

my $this_time = sql_datetime(time());
my $out = "";
$out .= "Files on jet available for grid viewer display at $this_time:\n";

my $cmd;
my $HRRR_path = "/home/rtrr/hrrr";
# HRRR isobaric files
$cmd = qq{/usr/bin/find $HRRR_path/ -name "wrfprs_hrconus*"|sort};
#print "cmd is $cmd\n";
my %fcsts_per_vtime;
open(LINES,"$cmd|") ||
    die "cannot execute $cmd: $!";
while (<LINES>) {
    #print;
    my($year,$mon,$day,$hour,$fcst_proj);
    if(($year,$mon,$day,$hour,$fcst_proj) =
       m|$HRRR_path/(\d{4})(\d{2})(\d{2})(\d{2}).*_(\d+).grib2|) {
	#print "$_ $year,$mon,$day,$hour,$fcst_proj\n";
	my $run_secs = timegm(0,0,$hour,$day,$mon-1,$year);
	my $valid_time = sql_datetime($run_secs + 3600*$fcst_proj);
	push(@{$fcsts_per_vtime{$valid_time}},$fcst_proj);
    }
}
$out .= "\nHRRR Isobaric files\n";
$out .= "  valid time         fcsts\n";
foreach my $vtime (sort keys %fcsts_per_vtime) {
    $out .= "$vtime: " . join(" ",reverse @{$fcsts_per_vtime{$vtime}}) . "\n";
}

my $RR_path = "/home/rtrr/rr";
# RR native files
$cmd = qq{/usr/bin/find $RR_path/ -name "wrfnat_rr*"|sort};
#print "cmd is $cmd\n";
%fcsts_per_vtime=();
open(LINES,"$cmd|") ||
    die "cannot execute $cmd: $!";
while (<LINES>) {
    #print;
    my($year,$mon,$day,$hour,$fcst_proj);
    if(($year,$mon,$day,$hour,$fcst_proj) =
       m|$RR_path/(\d{4})(\d{2})(\d{2})(\d{2}).*_(\d+).grib2|) {
	#print "$_ $year,$mon,$day,$hour,$fcst_proj\n";
	my $run_secs = timegm(0,0,$hour,$day,$mon-1,$year);
	my $valid_time = sql_datetime($run_secs + 3600*$fcst_proj);
	push(@{$fcsts_per_vtime{$valid_time}},$fcst_proj);
    }
}
$out .= "\nRR Native files\n";
$out .= "  valid time         fcsts\n";
foreach my $vtime (sort keys %fcsts_per_vtime) {
    $out .= "$vtime: " . join(" ",reverse @{$fcsts_per_vtime{$vtime}}) . "\n";
}
#print $out;
# gsi files from RR
my %types_per_vtime;
$cmd = qq{/usr/bin/find $RR_path/ -name "diag_results.conv*"|sort};
#print "cmd is $cmd\n";
open(LINES,"$cmd|") ||
    die "cannot execute $cmd: $!";
while (<LINES>) {
    my($year,$mon,$day,$hour,$type) =  m|$RR_path/(....)(..)(..)(..).*_(.*)|;
    #print "$year,$mon,$day,$hour,$type\n";
    my $valid_time = "$year-$mon-$day ${hour}Z";
    push(@{$types_per_vtime{$valid_time}},$type);
}
$out .= "\nRR GSI files\n";
$out .= "  valid time    types\n";
foreach my $vtime (sort keys %types_per_vtime) {
    $out .= "$vtime: " . join(" ",@{$types_per_vtime{$vtime}}) . "\n";
}
print $out;
$sth_replace->execute($this_time,$out);

sub sql_datetime {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
		   $year,$mon,$mday,$hour,$min,$sec);
}
