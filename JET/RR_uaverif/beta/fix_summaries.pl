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
$ENV{DBI_DSN} = "DBI:mysql:ruc_ua_sums2:wolphin";
my $dbh = DBI->connect(undef,undef,undef, {PrintError => 1});
my $query = "";
my $model = "FIM_prs%";
$query = qq{show tables like "$model\\_%"};
my $sth = $dbh->prepare($query);
$sth->execute();
my $table;
$sth->bind_columns(\$table);
while($sth->fetch()) {
    print "$table\n";
    $query =<<"EOI"
alter table $table
drop N_dRoT,
drop sum_dRoT,
drop sum2_dRoT
EOI
;
    print "$query\n";
    $dbh->do($query);
}
    
#add (
#N_dRoT smallint comment "N RH wrt obs. T, in percent",
#sum_dRoT float comment "sum RH wrt obs. T, in percent",
#sum2_dRoT float comment "sum squared RH wrt obs. T, in percent"
#)
