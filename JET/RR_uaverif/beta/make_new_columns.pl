#!/usr/bin/perl
use strict;
use strict;
use Time::Local;
use DBI;
$ENV{DBI_DSN} = "DBI:mysql:ruc_ua_sums2:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 0, PrintError => 1});
my $query;
my $model;
my @regions;
foreach $model (qw(HRRR)) {
    $query =<<"EOI"
select regions from ruc_ua.regions_per_model where 1=1
and model = "$model"
EOI
;
    my @result = $dbh->selectrow_array($query);
    @regions = split(/,/,$result[0]);
    print "regions for $model are @regions\n";

foreach my $reg  (@regions) {
    my $new_table = "${model}_Areg$reg";
    $query = qq{show tables like "$new_table"};
    my($found_table) = $dbh->selectrow_array($query);
    if($found_table) {
	# add new columns
	$query =<<"EOI"
alter table $new_table
add column `sum_ob_t` float DEFAULT NULL COMMENT 'ob, in celsius' after N_dt
, add column `sum_ob_R` float DEFAULT NULL COMMENT 'ob RH, in percent' after N_dR;
EOI
    ;
	print "query is \n$query;\n";
	my $n_rows = $dbh->do($query);
	print "$n_rows rows returned for $new_table\n";
    }
}
}

