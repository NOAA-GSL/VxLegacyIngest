#!/usr/bin/perl
use strict;
my $thisDir = $ENV{PBS_O_WORKDIR};
unless($thisDir) {
    # we've been called locally instead of qsubbed
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}
#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";

# connect to the database
use DBI;
$ENV{DBI_DSN} = "DBI:mysql:acars_RR:wolphin.fsl.noaa.gov;mysql_local_infile=1";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});

my $query = qq{show tables like "%sums"};
my $sth = $dbh->prepare($query);
$sth->execute();
my $table;
$sth->bind_columns(\$table);
while($sth->fetch()) {
    $query = "delete from $table where date >= '2015-01-12' and date <= '2015-02-12'";
    my $rows = $dbh->do($query);
    #print "$query\n";
    print "$rows rows deleted from $table\n";
}
