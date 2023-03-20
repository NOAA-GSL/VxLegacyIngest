#!/usr/bin/perl  
#gets a sorted list of usage
open(U,"/bin/ps uaxww|");
$fline= <U>;
print "$fline";
@lines = <U>;
@lines = sort by_usage @lines;
for($i=0;$i<10;$i++) {
    print $lines[$i];
}
print `uptime`;
sub by_usage($a $b) {
    $cpu_a = (split(/\s+/,$a))[2];
    $cpu_b = (split(/\s+/,$b))[2];    
    $cpu_b <=> $cpu_a;
}
    
