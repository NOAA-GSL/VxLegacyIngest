# set connection parameters for this directory; different for each supercomputer
$ENV{DBI_HOST} = "<what the MySQL db URL looks like on this machine>";
$ENV{DBI_DB} = "visibility";
$ENV{DBI_DSN} = "DBI:mysql:$ENV{DBI_DB}:host=$ENV{DBI_HOST}";
$ENV{DBI_USER} = "<user with write privilege>";
$ENV{DBI_PASS} = "<password>";
$ENV{AVID_machine} = "< set the machine as a env variable (jet or hera, so far; not used yet)>";
$ENV{vis_purge_time_days} ] = "<float, used by vis_driver.pl, update_persis.pl and get_vis_obs.pl to purge tmp dir>"
