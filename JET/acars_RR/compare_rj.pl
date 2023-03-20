sub compare_rj {
    my ($new_file,$old_file) = @_;

#my $recipients = "Bill.Moninger\@noaa.gov,Stan.Benjamin\@noaa.gov";
#my $recipients = "Bill.Moninger\@noaa.gov";
my $recipients = "";

    if($recipients ne "") {
	open(MAIL,"|/usr/sbin/sendmail -t");
	print MAIL <<"EOI";
MIME-Version: 1.0
To: $recipients
From: Bill.Moninger\@noaa.gov (cron on wcron1)
Subject: Aircraft Reject List Update
Content-Type: text/html;  charset=us-ascii
Content-Transfer-Encoding: 7bit

<pre>
(Automated message)
EOI
    ;
    }
my ($tail,$i,$j,%old_line,%new_line,%all);

open(OLD,$old_file);
my $n_old=0;
while(<OLD>) {
    if(/^;/) {
	next;
    }
    $n_old++;
    ($tail) = split;
    $old_line{$tail} = $_;
    $all{$tail} = $tail;
};
close OLD;

open(NEW,$new_file);
my $n_new = 0;
while(<NEW>) {
    if(/^;/) {
	next;
    }
    $n_new++;
    ($tail) = split;
    $new_line{$tail} = $_;
    $all{$tail} = $tail;
}
close NEW;

print "comparing $old_file (old) and $new_file (new)\n";
print "mailing results to $recipients\n";

if($recipients ne "") {
    print MAIL <<"EOI";
New reject list is $new_file with $n_new entries
Old reject list is $old_file with $n_old entries

List of aircraft added and removed from the reject list.
   
             ;tail    errors  FSL    MDCRS    N   bs_T Std_T  bs_S std_S bs_D std_D std_W rms_W bs_RH std_RH       (failures)
EOI
    ;
$i=1;
$j=1;
foreach $tail (sort keys %all) {
    if(defined $old_line{$tail} &&
       defined $new_line{$tail}) {
	# tail is on both lists
	next;
    } elsif (defined $old_line{$tail}) {
	# on old list but not new
	printf (MAIL "removed %3d: $old_line{$tail}",$j++);
    } else {
	# on new list but not old
	printf(MAIL "  added %3d: $new_line{$tail}",$i++);
    }
}
close(MAIL);
}
}

1;
