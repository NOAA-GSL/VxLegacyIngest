# set connection parameters for this directory
$ENV{DBI_HOST} = "wolphin";
$ENV{DBI_DB} = "visibility";
$ENV{DBI_DSN} = "DBI:mysql:mysql_local_infile=1:$ENV{DBI_DB}:host=$ENV{DBI_HOST}";
$ENV{DBI_USER} = "wcron0_user";
$ENV{DBI_PASS} = "cohen_lee";
# set the machine as a env variable (jet or hera, so far)
$ENV{AVID_machine} = "jet";
$ENV{vis_purge_time_days} = "0.5";

