#!/usr/bin/perl
for(my $i = -1;$i>-730;$i--) {
    print "./gen_persis.pl $i\n";
    system("./gen_persis.pl $i\n");
}
	
