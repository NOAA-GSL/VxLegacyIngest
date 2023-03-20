#!/usr/bin/perl -T
use strict;
$ENV{PATH} = "";
$ENV{ENV} = "/bin/sh";
my $DEBUG=0;
use DBI;


my ($safe_arg) = $ENV{model_sounding_file} =~ /(.*)/;
open(OUT,">$safe_arg") ||
    die "problem opening $safe_arg for writing\n";

my $model = $ARGV[0];
my $site = $ARGV[1];
my $sounding_directory = $ARGV[2];
my $desired_file = $ARGV[3];
# parse the input to get info needed for soundings stored in the database.
my($valid_time,$fcst_len) = $desired_file =~ /(.*)_(.*).gz/;
#print DEBUG "$model, $site, $valid_time, $fcst_len\n";

if(get_from_database($valid_time,$model,$site,$fcst_len)) {
    exit(0);
}

my $output_file = 
my $unsafe_arg = "";

if(-f "$sounding_directory/$desired_file") {
    $unsafe_arg = "/bin/gunzip --stdout $sounding_directory/$desired_file";
} else {
    # look in the tar file
    $unsafe_arg = "/bin/tar -xOf $sounding_directory/soundings.tar $desired_file|/bin/zcat";
}

my ($safe_arg) = $unsafe_arg =~ /(.*)/;
open(F,"$safe_arg|") ||
    die "BIG problem executing |$safe_arg|: $!";

while(<F>) {
    print OUT;
    if($DEBUG) {
	print;
    }
}
print OUT "\n";
close F;

sub get_from_database {
    my($time,$data_source,$name,$desired_fcst_len) = @_;
    open(DEBUG,">>model_debug.txt")||
	die "cannot open raob_debug.txt: $!";
    #print DEBUG "$time,$desired_fcst_len,$data_source,$name\n";
    my $found_sounding = 0;
    require "./set_connection.pl";
    $ENV{DBI_DSN} = "DBI:mysql:soundings:wolphin.fsl.noaa.gov";
    my $dbh = DBI->connect(undef,undef,undef, {RaiseError => 1});
    # first get primary airport name if any
    my $fcst_len_clause;
    if($desired_fcst_len >= 0) {
	$fcst_len_clause = "and fcst_len = $desired_fcst_len";
    } else {
	$fcst_len_clause = "order by fcst_len";
    }
    my $sth_get;
    my $data;
    my $sql_datetime = sql_datetime($time);
    my $table = "${data_source}_raob_soundings";
    my $query = qq(show tables like "$table");
    #print DEBUG "query is $query\n";
    my $result = $dbh->selectrow_array($query);
    print "result is $result\n";
    my $model_clause="";
    unless($result) {
	$table = "model_raob_soundings";
	$model_clause = qq{and model = '$data_source'};
    }
    #print DEBUG "table is $table\n";
    $query =<<"EOI"
select s from $table
where 1=1
and site = '$name'
and time = '$sql_datetime'
$model_clause
$fcst_len_clause
EOI
;
    if($DEBUG) {
	#print DEBUG "$query\n";
    }
    $sth_get = $dbh->prepare($query);
    $sth_get->execute();
    $sth_get->bind_columns(\$data);
    $sth_get->fetch();
    if($data) {
	if($DEBUG) {print DEBUG "got sounding from $table\n";}
	$found_sounding = 1;
    }
    if($found_sounding) {
	use Compress::Zlib;
	my $out_sdg = Compress::Zlib::memGunzip($data);
	# print out each line of the sounding
	foreach my $line (split(/\n/,$out_sdg)) {
	    print OUT $line;
	    if($DEBUG) {print $line;}
	    print OUT "\n";
	    if($DEBUG) {print "\n";}
	}
	print OUT "\n";
	if($DEBUG) {print "\n";}
    } else {
	if($DEBUG) {
	    print DEBUG "sounding NOT found in $table for $data_source,$name,$sql_datetime,$desired_fcst_len\n";
	}
    }
    close(DEBUG);
    return $found_sounding;
}

sub sql_datetime {
    my $time = shift;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    $mon++;
    $year += 1900;
    return sprintf("%4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
		   $year,$mon,$mday,$hour,$min,$sec);
}

