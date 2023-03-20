#!/usr/bin/perl
use strict;
my $DEBUG=1;
use DBI;
#set database connection parameters
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
$ENV{DBI_DSN} = "DBI:mysql:files_from_jet:wolphin";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $sth;
my $query="";
$query =<<"EOI"
select contents from files 
where name = ?
EOI
    ;
my $sth_get = $dbh->prepare($query);

my $name = $ARGV[0];
#print "name is $name\n";

my $contents="";
$sth_get->execute($name);
$sth_get->bind_columns(\$contents);
$sth_get->fetch();
open(OUT,">$name") ||
    die "cannot write file $name\n";

print OUT $contents;
close OUT;

$query=<<"EOI"
delete from files
where name = '$name'
EOI
    ;
$dbh->do($query);
exit(0);
