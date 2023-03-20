# Generated automatically from Makefile.PL.in by configure.
use ExtUtils::MakeMaker qw(WriteMakefile);


# The existence of the ./*/Makefile.PL file causes MakeMaker
# to automatically include Makefile code for the targets
#	all, clean, realclean and */Makefile
# which perform the corresponding action in the subdirectory.

$version = "1.2.3";
                           
WriteMakefile(
    'NAME'     => 'NetCDF',
    'DISTNAME' => "netcdf-perl-" + $version,
    'VERSION'  => $version,
    'INC'     => '-I/apps/netcdf/3.6.3-intel/include',
    'OBJECT' => 'NetCDF.o',
    'LIBS' => "-L/apps/netcdf/3.6.3-intel/lib -lnetcdf ",
    'clean' => {'FILES' => "*.nc NetCDF.bs"},
    'realclean' => {'FILES' => "*.old Makefile.PL"}
);
