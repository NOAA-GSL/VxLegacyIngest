#!/usr/local/perl5/bin/perl
$thisDir = ".";
opendir(DIR,$thisDir) or die "can't open $thisDir: $!";
while (defined ($file = readdir DIR)) {
    if (-T "$thisDir/$file" &&
	$file =~ /.java$/) {
	open(TMP,">t") or die "Can't open t: $!";;
	print TMP <<"EOI";
/*
Open Source License/Disclaimer, 
Forecast Systems Laboratory
NOAA/OAR/FSL
325 Broadway Boulder, CO 80305 

This software is distributed under the Open Source Definition, which
may be found at http://www.opensource.org/osd.html. In particular,
redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:  
<ul>
<li> Redistributions of source code must retain this notice, this list of
  conditions and the following disclaimer. 

<li> Redistributions in binary form must provide access to this notice,
  this list of conditions and the  following disclaimer, and the
  underlying source code.
  
<li> All modifications to this software must be clearly documented, and
  are solely the responsibility of the agent making the
  modifications.
  
<li> If significant modifications or enhancements are made to this
  software, the Forecast Systems Laboratory should be notified.
</ul>
    
THIS SOFTWARE AND ITS DOCUMENTATION ARE IN THE PUBLIC DOMAIN AND ARE
FURNISHED "AS IS." THE AUTHORS, THE UNITED STATES GOVERNMENT, ITS
INSTRUMENTALITIES, OFFICERS, EMPLOYEES, AND AGENTS MAKE NO WARRANTY,
EXPRESS OR IMPLIED, AS TO THE USEFULNESS OF THE SOFTWARE AND
DOCUMENTATION FOR ANY PURPOSE. THEY ASSUME NO RESPONSIBILITY (1) FOR THE
USE OF THE SOFTWARE AND DOCUMENTATION; OR (2) TO PROVIDE TECHNICAL
SUPPORT TO USERS. 
*/
EOI
    ;
	$already_done=0;
	open(JAVA,"$thisDir/$file") or die "Can't open $thisDir/$file: $!";
	while(<JAVA>) {
	    if(m|Open Source License/Disclaimer|) {
		$already_done = 1;
	    }
	    print TMP;
	}
	close(JAVA);
	close(TMP);
	unless ($already_done) {
	    print "updated $thisDir/$file\n";
	    system("/usr/bin/mv t $thisDir/$file");
	} else {
	    unlink "t";
	}
    }
}

exit 0;
