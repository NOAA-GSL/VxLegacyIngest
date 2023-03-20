#!/usr/local/perl5/bin/perl
# script to monitor number of acars ingested into MAPS in each 24-hr period
require "timelocal.pl";
chdir "/home/mtn1/moninger/utilities" ||
    die "Can't change to ~moninger/utilities!\n";

$recipients = "moninger,benjamin,stanley," .
    "wd41ja\@sun1.wwb.noaa.gov"; # Jeff Ator

# USE THE LINE BELOW FOR DEBUGGING!
#$recipients = moninger;

@weekDay=("Sunday","Monday","Tuesday","Wednesday","Thursday",
	   "Friday","Saturday");
# work in GMT
$ENV{TZ} = "GMT";
$time = time();
# @timeArray = ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
@timeArray = gmtime($time);
print "The current time is @timeArray\n";
$nDays = $ARGV[0];
print "ndays = $nDays\n";
# stop today at 0Z 
$days1970 = int($time/86400);
$lastTime=$days1970 * 86400;
print "lastTime = $lastTime\n";
$startTime = $lastTime - 86400 - $nDays*86400;

@timeArray = gmtime($startTime);
print "The start time is @timeArray\n";

open (ACARS,"<pirepcnt");
for($stopTime = $startTime+86400;
    $stopTime <= $lastTime;
    $startTime = $stopTime, $stopTime += 86400) {
$nAcars=0;
$nRuns=0;
TIMELOOP: for($thisTime = $startTime;
    $thisTime < $stopTime ;
    $thisTime += 10800) {	# increment by 3 hours

    #get atime
    ($sec,$min,$hour,$mday,$mm1,$year,$wday,$ydaym1,$isdst)=gmtime($thisTime);
    $yday=$ydaym1+1;		# $ydaym1 starts at 0 for Jan 1!
    $atime = sprintf("$year$yday%02.2d00",
		       $hour);

    while(<ACARS>) {
	if(/^ $atime/) {
	    print;
	    $nRuns++;
	    /.*= (.*)/;
	    $nAcars += $1;
	    next TIMELOOP;
	}
    }
    #if we get here, we went too far in ACARS.  Do a sloppy rewind
    close ACARS;
    open (ACARS,"<pirepcnt");

}
#note: the expected number below is too high for weekends (so don't run
#this on weekends!)

print "$nAcars ACARS ingested during $nRuns MAPS runs on day $yday ($weekDay[$wday]).\n";

$expected = 2000 * $nRuns;
if($nAcars < $expected) {
    print "Sending warning mail to $recipients\n";
    open(MAIL,"|/usr/lib/sendmail $recipients");
    print MAIL <<"EOI";
To: $recipients    
From: moninger/utilities/watch-acars.pl    
Subject: WARNING!  Fewer ACARS than expected!
only $nAcars ACARS ingested during $nRuns MAPS runs on day $yday ($weekDay[$wday]).
Last 100 lines of file pirepcnt follow:
    
EOI
open(TMP,"tail -100 pirepcnt|");
while (<TMP>) {
    print MAIL $_;
}
close (TMP);
 
}
}
