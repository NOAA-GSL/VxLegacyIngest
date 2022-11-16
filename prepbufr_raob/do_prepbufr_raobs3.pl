#!/bin/perl
#
#SBATCH -J pb_RAOB3
#SBATCH --mail-user=verif-amb.gsl@noaa.gov
#SBATCH --mail-type=FAIL
#SBATCH -A amb-verif
#SBATCH -n 1
#SBATCH -p service
#SBATCH -t 00:10:00
#SBATCH -D .
#SBATCH --mem=16G
#SBATCH -o tmp/%x.oe.%j.job
#
#
# clean up tmp directory
opendir(DIR,"tmp") ||
    die "cannot open tmp/: $!\n";
my @allfiles = grep !/^\.\.?$/,readdir DIR;
foreach my $file (@allfiles) {
    $file = "tmp/$file";
    #print "file is $file\n";
    # untaint
    $file =~ /(.*)/;
    $file = $1;
    if(-M $file > 2.0) {	# age in days
	print "unlinking old file $file\n";
        unlink "$file" || print "Can't unlink $file $!\n";
    }
}
closedir DIR;

my $cmd = "./get_prepbufr_raobs3.py $ARGV[0] $ARGV[1] $ARGV[2]";
print("cmd is $cmd\n");
if(system($cmd) != 0) {
    exit(0);
}

my $cal_secs = `get_cal_secs.py $ARGV[1]`;
chomp $cal_secs;
$ENV{CLASSPATH} =  "/home/amb-verif/javalibs/mysql-connector-java-5.1.6/mysql-connector-java-5.1.6-bin.jar:.";
$cmd = "~/java8/java -Xmx256m Verify3 dummy RAOB $cal_secs $cal_secs 0";
print("\n$cmd\n");
system($cmd) &&
    die "could not run Verify3: $!";
print("\ncomparing prepBUFR RAOB locaations for the past month with the old RAOB locations in the ruc_ua db...");
$cmd = "./update_metadata2.py";
print ("\n$cmd\n");
system($cmd) &&
    die "could not run $cmd: $!";

 
