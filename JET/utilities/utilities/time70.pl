#!/usr/bin/perl 
#print times
#require "timelocal.pl";
use Time::Local;

#set up some nice variables
@month=(Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec);
@day=(Sun,Mon,Tue,Wed,Thu,Fri,Sat);
print "Arguments (optional): hour month-day month year (1 or 2 digits)\n".
      "                  or: secs-since-1970\n";

($myhour,$myday,$mymonth,$myyear)=@ARGV;
$time = time();
($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
if(defined($myhour)) {
    $hour=$myhour;
}
if($myday) {
    $mday=$myday;
}
if($mymonth) {
    $mon = $mymonth-1;
}
if($myyear) {
    $year=$myyear;
}
if($hour > 23 ) {
    #assume the first arg is secs since 1970
    $time=$myhour;
} else {
    $time=timegm(0,0,$hour,$mday,$mon,$year);
}
&printTime($time);
$secs_per_12=86400/2;
$time = int($time/$secs_per_12)*$secs_per_12;
&printTime($time);
for($i=0;$i<10;$i++) {
    $time -= $secs_per_12;
    &printTime($time);
}

sub printTime {
    my ($time)=@_;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($time);
    $thisMonth=$month[$mon];
    $dayOfWeek=$day[$wday];
    $jday=$yday+1;
    $year += 1900;
    printf "$dayOfWeek $mday $thisMonth $year %02d:%02d:%02d (day $jday)".
	" = $time\n",$hour,$min,$sec;
}
