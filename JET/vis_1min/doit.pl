#!/usr/bin/perl
for($i=-24;$i>-72;$i--) {
    my $arg = "./update_persis.pl $i\n";
    print($arg);
    system($arg);
}
    
