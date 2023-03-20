#!/usr/bin/perl

# this script will delete one time inside the database for an entire model.
# to be used if there is either a bad RAOB or bad model run/file

use strict;
use POSIX 'strftime';

my $DEBUG=1;
use DBI;
my $model = $ARGV[0];
my $delete_time = $ARGV[1];
unless($model) {
    die "Usage: delete_model_sum.pl <model> <time (epoch)>\n";
}

#change to the proper directory
use File::Basename; 
my ($basename,$thisDir) = fileparse($0);

use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
$thisDir = $ENV{PWD};

#set database connection parameters
require "./set_connection.pl";
$ENV{DBI_DSN} = "DBI:mysql:ruc_ua_sums2:wolphin.fsl.noaa.gov";

# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {PrintError => 1});
my $sth;
my $query="";

$query = <<"EOI"
select regions from ruc_ua.regions_per_model where model = "$model"
EOI
;
my @result = $dbh->selectrow_array($query);
my @regions = split(/,/,$result[0]);
print "regions are @regions\n";

$query = <<"EOI"
select fcst_lens from ruc_ua.fcst_lens_per_model where model = "$model"
EOI
;
my @result = $dbh->selectrow_array($query);
my @fcst_lens = split(/,/,$result[0]);
print "fcst_lens are @fcst_lens\n";


my $date = strftime '%Y-%m-%d', gmtime $delete_time;
print "date is $date\n";

my $date_hour = strftime '%H', gmtime $delete_time;
print "hour is $date_hour\n";

foreach my $region (@regions) {
foreach my $fcst_len (@fcst_lens) {

$query = <<"EOI"
delete from ${model}_Areg${region} where date = "$date" and hour = $date_hour and fcst_len = $fcst_len
EOI
;
print $query;
$dbh->do($query);
}}
