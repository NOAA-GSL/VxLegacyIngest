#!/usr/bin/perl
use strict;
use strict;
use Time::Local;
use DBI;
$ENV{DBI_DSN} = "DBI:mysql:ruc_ua:wolphin.fsl.noaa.gov";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
# connect to the database
my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 0, PrintError => 1});
my $query;
my $model;
my @raobs = qw(ABQ ABR ALY AMA APX BIS BMX BNA BOI BRO BUF CAR CHH CHS CRP DNR DRA DRAne DRT DTX DVN EPZ EYW FFC FGZ FSI FWD GGW GJT GRB GSO GYM GYX IAD ILN ILX INL JAN JAX LAP LBF LCH LKN LMN LZK MAF MCV MFL MFR MHX MPX MTY NKX OAK OAX OKX OTX OUN PIT REV RIW RNK SGF SHV SIL SLC SLE TBW TFX TLH TOP TWC UIL UNR VBG WAL WPL WQI XMR YLW YMO YMW YNN YWA);

my $i=0;
foreach my $raob (@raobs) {
    $i++;
    $query = qq{update metadata set reg = concat(reg,',14') where name = "$raob"};
    my $n_rows = $dbh->do($query);
    if($n_rows < 1) {
	print "$n_rows rows updated for $raob\n";
    }
}
print "i is $i\n";

