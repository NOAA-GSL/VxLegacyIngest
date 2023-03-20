#!/bin/sh -f
rm DELETEME > /dev/null 2>&1
/usr/local/perl5/bin/perldoc $1 > DELETEME
more DELETEME
rm DELETEME
