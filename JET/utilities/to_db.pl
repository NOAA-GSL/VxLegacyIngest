#!/usr/bin/perl
use strict;
my $DEBUG=1;
use DBI;
# set connection parameters for this directory
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
$ENV{DBI_DSN} = "DBI:mysql:files_from_jet:wolphin";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
my $sth;
my $query="";
$query =<<"EOI"
replace into files 
(name,contents)
values(?,?)
EOI
    ;
my $sth_load = $dbh->prepare($query);

my $name = $ARGV[0];
print "name is $name\n";

my $contents="";
while(<>) {
    $contents .= $_;
}
#print "contents is |$contents|\n";
$sth_load->execute($name,$contents);
exit(0);
