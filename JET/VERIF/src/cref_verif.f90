program cref_verif
!=================================================================================
!
! This program creates verification statistics, grids, and figures for 
! Composite Reflectivity.  The input grid can be LamCon or EquiDistant Cyl,
! and you can upscale or downscale as desired to an output grid of either of
! these two types.  Adding input grids is fairly trivial.  For the interpolation, 
! NCEP's IPLIB is used.
!
! INPUTS: input namelist and NetCDF interpolated grids
! 
! OUTPUTS: Verification statistical summaries
!
! Written by: Patrick Hofmann
! Last Update: 21 SEP 2010
!
!=================================================================================
use netcdf
use verif_mod

implicit none
integer, external :: iargc

! Define variables
integer                           :: iunit, io

character(len = max_name_len)     :: nml_file
                                     
type(cont_table_type)             :: conus_table, west_table, east_table
type(stats_type)                  :: conus_stats, west_stats, east_stats
type(state_type)                  :: model_state, obs_state, verif_state

!---------------------------------------------------------------------------------

! Get namelist file name from command line
if(iargc() == 0) stop "You must specify the namelist file to read"
call getarg(1,nml_file)

! Read namelist values
open(unit=5,file=trim(nml_file),action='read')
read(5, nml = main_nml,  iostat = io)
if(io /= 0) stop "(MAIN) main_nml not opened successfully!"
read(5, nml = verif_nml, iostat = io)
if(io /= 0) stop "(MAIN) verif_nml not opened successfully!"
close(5)

! Read model data
call read_model_nc_file(nc_out_var,model_out_file,model_state)

! Read observation data
call read_obs_nc_file(nc_out_var,obs_out_file,obs_state)

! Calculate contingency table
call calc_contingencies(obs_state,model_state,verif_state,threshold,conus_table,west_table,east_table)

! Write verification grid to NetCDF file
call write_interp_state('verif',nc_out_var,interp_grid,verif_out_file,verif_state)

! Calculate verification statistics
call calc_statistics(conus_table,conus_stats)
call calc_statistics(west_table,west_stats)
call calc_statistics(east_table,east_stats)

! Write summary statistics to ASCII file
call write_verif_ascii_file(conus_stats,conus_table,conus_out_file)
call write_verif_ascii_file(west_stats,west_table,west_out_file)
call write_verif_ascii_file(east_stats,east_table,east_out_file)

print *, "Program cref_verif finished"

!=================================================================================
end program cref_verif
