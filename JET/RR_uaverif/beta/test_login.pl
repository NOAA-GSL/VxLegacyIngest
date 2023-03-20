#!/usr/bin/perl
#
# THIS USES A NEW PER-MODEL STRUCTURE FOR THE SOUNDINGS TABLE(S)
#
#  Set the name of the job.
#$ -N a_r_st3
#  Make sure that the .e and .o file arrive in the working directory
#$ -cwd
#  Set the account
#$ -A wrfruc
#  Ask for 1 cpus of type service
#$ -pe service 1
#  My code is re-runnable
#$ -r y
# send mail on abort
#$ -m a
#$ -M verif-amb.gsd@noaa.gov
#
#  The max walltime 
#$ -l h_rt=01:00:00
#
#$ -e tmp/
#$ -o /dev/null
#
use strict;
my $DEBUG=1;
use DBI;


#useful DEBUGGING info vvvvvvvvvvvvvv
if($DEBUG) {
    foreach my $key (sort keys(%ENV)) {
        #print "$key: $ENV{$key}\n";
    }
}

# get login environment
%ENV = get_login_env();
print "\n\nAFTER getting login env:\n";
#useful DEBUGGING info vvvvvvvvvvvvvv
if($DEBUG) {
    foreach my $key (sort keys(%ENV)) {
        print "$key: $ENV{$key}\n";
    }
}

sub get_login_env {
  open (SUBSHELL, "printenv.sh|") or
      die "could not open subshell: $!";
  my @env = <SUBSHELL>;
  my $env = join("",@env);
  my @pieces = ($env =~ m/^(.*?)=((?:[^\n\\]|\\.|\\\n)*)/gm);
  s/\\(.)/$1/g foreach @pieces;
  #print "pieces are @pieces\n";
  return @pieces;
}

my $thisDir = $ENV{SGE_O_WORKDIR};
my $qsubbed=1;
unless($thisDir) {
    # we've been called locally instead of qsubbed
    $qsubbed=0;
    use File::Basename; 
    my ($basename,$thisDir2) = fileparse($0);
    $thisDir = $thisDir2;
}
my $output_id = $ENV{JOB_ID} || $$;


#change to the proper directory
use Cwd 'chdir'; #use perl version so this isn't unix-dependent
chdir ("$thisDir") ||
          die "Content-type: text/html\n\nCan't cd to $thisDir: $!\n";
$thisDir = $ENV{PWD};
exit;
