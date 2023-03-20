#!/usr/bin/perl
# subroutine gets julian day and [optional] year as arguments
# returns a list with (weekday, monthDay, month_num, year)
use Time::Local;
#require "timelocal.pl";
use strict vars;

sub jy2mdy {
    my ($i,$julday,$leap,$timeSecs);
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
    ($julday,$year)=@_;
    
    #daytab holds number of days per month for regular and leap years
    my (@daytab) =(0,31,28,31,30,31,30,31,31,30,31,30,31,
	              0,31,29,31,30,31,30,31,31,30,31,30,31);
    my (@month)=(Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec);
    my (@day)=(Sun,Mon,Tue,Wed,Thu,Fri,Sat);


    #see if year was defined
    if($year == 0) {
	$timeSecs=time();
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
	    = gmtime($timeSecs);
	$year += 1900;
    } elsif ($year < 1000) {
	#2-digit year was (probably) input
	if($year > 70) {
	    $year += 1900;
	} else {
	    $year += 2000;
	}
    }

    #see if the year is a leap year
    $leap = ($year%4 == 0 && $year%100 != 0) || ($year%400 == 0);
    my $tt = $year%400;
    for($i=1,$mday = $julday ; $mday  > $daytab[$i + 13 * $leap]  ; $i++) {
	$mday -= $daytab[$i + 13 * $leap];
    }
    $mon=$i-1;
    my $dum;
    $timeSecs=timegm(0,0,0,$mday,$mon,$year);
    ($dum,$dum,$hour,$mday,$mon,$dum,$wday,$yday,$isdst)
	= gmtime($timeSecs);
    #return a 4 digit year
    ($day[$wday],$mday,$mon,$year);
}

1;				# provide a return value
	

