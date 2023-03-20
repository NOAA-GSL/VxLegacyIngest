#!/usr/bin/perl

use strict;
my $DEBUG=1;

# PREAMBLE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
#for security
$ENV{'PATH'}="";

$ENV{'TZ'}="GMT";

use DBI;
#connect
require "./set_connection.pl";
$ENV{DBI_DSN} = "DBI:mysql:surface_sums:wolphin";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $query = "";

foreach my $model qw(GLMP) {
    my @regions = qw[ALL_HRRR E_HRRR W_HRRR HWT STMAS_CI];
    #@regions = qw[ALL_RR1];
    my @fcst_lens = (1,3,6,9,12);
    #@fcst_lens = (0);
foreach my $fcst_len (@fcst_lens) {
foreach my $region (@regions) {
    my $table = "${model}_${fcst_len}_metar_q_${region}";
    $query = qq[
delete from $table where sum_ob_t is null];

    if($DEBUG) {
	print "$query;\n";
    }
    print Q "$query\n;\n\n";
    my $n_lines = $dbh->do($query);
    print "$n_lines lines deleted\n";

}
}}

$dbh->disconnect();
