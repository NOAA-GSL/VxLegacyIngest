#!/usr/local/perl5/bin/perl -w
#
# usage: cgrep [-lines] pattern files
#
# script to do a grep through files, and print out lines around the matched
# regular expression.
# patterned after cgrep in the Programming Perl book, p 271
$context = 3;

#we might want more or less context.

if ($ARGV[0] =~ /^-(\d+)$/) {
    $context=$1;
    shift;
    }

# get pattern and protect the delimiter.

$pat = shift;
$pat =~ s#/#\\/#g;

# loop over files
while ($file = shift) {
    open(F,$file) || next;
# First line of input will be middle of array.
# In the eval below, it will be $ary[$context].
#print "search file $file\n";
    @ary=();
$_ = <F>;
push(@ary,$_);

# Add blank lines before, more input after first line.

for (1 .. $context) {
    unshift(@ary,'');
    $_ = <F>;
    push(@ary,$_) if $_;
}

# Now use @ary as a silo, shifting and pushing.

eval <<LOOP_END;
  while (\$ary[$context]) {
      if (\$ary[$context] =~ /$pat/) {
	  print "______  $file vvv _______\n";
	  print \@ary, "\n";
      }
      \$_ = <F> if \$_;
      shift(\@ary);
      push(\@ary,\$_);
  }	
LOOP_END
    
}
