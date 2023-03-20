1;
use strict;
sub get_obs_at_hr_q {
    my ($valid_secs,$dbh) = @_;
    # don't try to create an hour table newer than 3 h old
    my $now_secs = time();
    my $now_str = gmtime($now_secs);
    my $valid_str = gmtime($valid_secs);
    if($now_secs - $valid_secs < 3*3600) {
	print "at $now_str, not enough time (3h) as elapsed to create hr_obs_$valid_secs valid at $valid_str!\n";
	return;
    }
    my $table = "hr_obs_$valid_secs";
    my $out_file = "tmp/$table.$$.tmp";
    use DBI;
    use Time::Local;
    my $valid_str = gmtime($valid_secs);
    my $query = "";
    my $sth;
    $dbh->do("use madis3");
    $query = qq|show tables like "$table"|;
    $sth = $dbh->prepare($query);
    $sth->execute();
    my($already_there) = $sth->fetchrow_array();
    $sth->finish();

    if(defined $already_there) {
	# see if it has anything in it!
	$query = "select count(*) from $table";
	$sth = $dbh->prepare($query);
	$sth->execute();
	my(@stuff) = $sth->fetchrow_array();
	if($stuff[0] == 0) {
	    print "table $table exists, but is empty! dropping it.\n\n";
	    $dbh->do("drop table $table");
	    $already_there=undef;
	}
    }
    if(defined $already_there) {
	print "$already_there exists. Not recreating it.\n";
	return;
    } else {
	open(OUT,">$out_file") ||
	    die "cannot open $out_file: $!";
	print "generating hr_obs table...";
	$query =<<"EOI"
create temporary table x1
(UNIQUE id_time (sta_id,time))
select sta_id,time,loc_id
 ,if(slpDD != 'X',slp,null) as slp
 ,if(tempDD != 'X',temp,null) as temp
 ,if(dpDD != 'X',dp,null) as dp
 ,if(wdDD != 'X',wd,null) as wd
 ,if(wsDD != 'X',ws,null) as ws
from obs_retro where 1=1
and obs_retro.time >= $valid_secs - 1800
and obs_retro.time < $valid_secs + 1800
EOI
;
print "$query\n";
$dbh->do($query);
$query=<<"EOI"
create temporary table x2
(index (sta_id,loc_id,min_dif))
select sta_id,loc_id,min(cast(abs(time - $valid_secs) as signed)) as min_dif
from x1
group by sta_id,loc_id
EOI
    ;
#print "$query\n";
$dbh->do($query);
$query=<<"EOI"
select x1.sta_id,x1.loc_id,lat,lon,elev,time,net,slp,temp,dp,ws,wd
from x1,x2,locations,stations
where x1.sta_id = x2.sta_id
and x1.loc_id = x2.loc_id
and x1.loc_id = locations.id
and x1.sta_id = stations.id
and cast(abs(x1.time - $valid_secs) as signed) = min_dif
group by sta_id,loc_id
EOI
    ;
#print "$query\n";
$sth = $dbh->prepare($query);
$sth->execute();
my($sta_id,$loc_id,$lat,$lon,$elev,$time,$net,$slp,$temp,$dp,$ws,$wd,$rh10);
$sth->bind_columns(\$sta_id,\$loc_id,\$lat,\$lon,\$elev,\$time,\$net,\$slp,\$temp,\$dp,\$ws,\$wd);
while($sth->fetch()) {
    if(defined $dp and defined $temp) {
	my $good_dp = $dp > $temp ? $temp : $dp;
	$rh10 = int(svpWobus($good_dp/10)/svpWobus($temp/10) * 100 * 10 + 0.5);
    } else {
	$rh10 = undef;
    }
    if(defined $temp || defined $ws) {
	print OUT "$sta_id,$loc_id,$lat,$lon,$elev,$time,$net".
	    nullor($slp).nullor($temp).nullor($dp).nullor($ws).nullor($wd).nullor($rh10)."\n";
    }
    #print  "$sta_id,$loc_id,$lat,$lon,$elev,$time,$net,".
	#nullor($slp).nullor($temp).nullor($dp).nullor($ws).nullor($wd).nullor($rh10)."\n";
}
$sth->finish();
$dbh->do("drop table x1");
$dbh->do("drop table x2");
close OUT;
my $query=<<"EOI"
CREATE TABLE IF NOT EXISTS $table (
  sta_id mediumint(8) unsigned NOT NULL,
  loc_id int(10) unsigned NOT NULL COMMENT 'id into "locations2" table',
  lat smallint(6) NOT NULL COMMENT 'degrees times 182',
  lon smallint(6) NOT NULL COMMENT 'degrees times 182',
  elev smallint(6) DEFAULT NULL COMMENT 'feet, MSL',
  time int(10) unsigned NOT NULL COMMENT 'seconds since 1/1/70',
  net varchar(15) NOT NULL DEFAULT '',
  slp smallint(6) DEFAULT NULL COMMENT 'sea level pressure in mb*10',
  temp smallint(6) DEFAULT NULL COMMENT 'temperature in farenheit*10',
  dp smallint(6) DEFAULT NULL COMMENT 'dewpoint in farenheit*10',
  ws smallint(5) unsigned DEFAULT NULL COMMENT 'wind speed in mph',
  wd smallint(6) DEFAULT NULL COMMENT 'wind direction in degrees true',
  rh smallint(6) DEFAULT NULL COMMENT 'rh in percent times 10',
  UNIQUE KEY time_id (time,sta_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1    
EOI
    ;
#print "$query\n";
$dbh->do($query);


$query =<<"EOI"
load data concurrent local infile "$out_file"
replace into table $table
columns terminated by ',' lines terminated by '\\n'
EOI
;
#print "$query\n";
my $n_obs = $dbh->do($query);
if($n_obs > 0) {
    print "created table $table with $n_obs obs valid at $valid_str\n";
    # update the metar table
    $query=<<"EOI"
insert ignore into metars (madis_id,name,lat,lon,elev)
select o.sta_id as madis_id,name,lat,lon,elev
from $table as o,stations
where 1=1
and o.sta_id = stations.id
and stations.net = 'METAR'
EOI
;
   #print "$query\n";
    my $rows = $dbh->do($query);
    print "$rows rows added to table metars\n";
    
} else {
    print STDERR "\n$table valid at $valid_str HAS NO OBS. Must reload obs from MADIS\n\n";
}	   
unlink($out_file) ||
    die "\n\nCANNOT UNLINK $out_file: $!\n\n";
}
}

sub nullor {
    my $val = shift;
    my $result = ',\\N';
    if(defined $val) {
	$result = ",$val";
    }
    return $result;
}

#C	Baker, Schlatter  17-MAY-1982	  Original version.
#C   THIS FUNCTION RETURNS THE SATURATION VAPOR PRESSURE ESW (MILLIBARS)
#C   OVER LIQUID WATER GIVEN THE TEMPERATURE T (CELSIUS). THE POLYNOMIAL
#C   APPROXIMATION BELOW IS DUE TO HERMAN WOBUS, A MATHEMATICIAN WHO
#C   WORKED AT THE NAVY WEATHER RESEARCH FACILITY, NORFOLK, VIRGINIA,
#C   BUT WHO IS NOW RETIRED. THE COEFFICIENTS OF THE POLYNOMIAL WERE
#C   CHOSEN TO FIT THE VALUES IN TABLE 94 ON PP. 351-353 OF THE SMITH-
#C   SONIAN METEOROLOGICAL TABLES BY ROLAND LIST (6TH EDITION). THE
#C   APPROXIMATION IS VALID FOR -50 < T < 100C.
sub svpWobus {
    my($tf) = @_;		# temperature in farenheit
    my $tx = ($tf - 32.)*5./9.;	# in Celsius
    my $pol = 0.99999683       + $tx*(-0.90826951e-02 +
      $tx*(0.78736169e-04   + $tx*(-0.61117958e-06 +
      $tx*(0.43884187e-08   + $tx*(-0.29883885e-10 +
      $tx*(0.21874425e-12   + $tx*(-0.17892321e-14 +
      $tx*(0.11112018e-16   + $tx*(-0.30994571e-19)))))))));
    my $esw_pascals = 6.1078/($pol**8.) *100.; 
    return($esw_pascals);
}
     
