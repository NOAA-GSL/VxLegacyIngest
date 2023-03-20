program do_verif
  !==========================================================================================
  !
  ! This program creates verification statistics, grids, and figures for 
  ! Composite Reflectivity, Precipitation Accumulation, VIP/VIL, and CCFP probabilities.  
  ! The input grid can be LamCon or EquiDistant Cyl,
  ! and you can upscale or downscale as desired to an output grid of either of
  ! these two types.  Adding input grids is fairly trivial.  For the interpolation, 
  ! NCEP's IPLIB is used.
  !
  ! INPUTS: input namelist and NetCDF interpolated grids
  ! 
  ! OUTPUTS: Verification statistical summaries
  !
  ! Written by: Patrick Hofmann
  ! Last Update: 04 MAR 2011
  !
  !===========================================================================================
  use netcdf
  use verif_mod
  
  implicit none
  integer, external :: iargc
  
  ! Define variables
  integer                           :: iunit, io
  
  character(len = max_name_len)     :: nml_file
  
  type(cont_table_type)             :: c_table, s_table, se_table, ne_table, &
                                       n_table
  type(stats_type)                  :: c_stats, s_stats, se_stats, ne_stats, &
                                       n_stats
  type(state_type)                  :: model_state, obs_state, verif_state
  
  !-------------------------------------------------------------------------------------------
  
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
  if (do_c) call calc_contingencies(obs_state,model_state,verif_state,threshold,'central',c_table)
  if (do_s)  call calc_contingencies(obs_state,model_state,verif_state,threshold,'south',s_table)
  if (do_se)  call calc_contingencies(obs_state,model_state,verif_state,threshold,'southeast',se_table)
  if (do_ne)    call calc_contingencies(obs_state,model_state,verif_state,threshold,'northeast',ne_table)
  if (do_n)    call calc_contingencies(obs_state,model_state,verif_state,threshold,'north',n_table)
  
  ! Write verification grid to NetCDF file
  call write_interp_state('verif',nc_out_var,interp_grid,verif_out_file,verif_state)
  
  ! Calculate verification statistics
  if (do_c) call calc_statistics(c_table,c_stats)
  if (do_s)  call calc_statistics(s_table,s_stats)
  if (do_se)  call calc_statistics(se_table,se_stats)
  if (do_ne)    call calc_statistics(ne_table,ne_stats)
  if (do_n)    call calc_statistics(n_table,n_stats)
  
  ! Write summary statistics to ASCII file
  if (do_c) call write_verif_ascii_file(c_stats,c_table,c_out_file)
  if (do_s)  call write_verif_ascii_file(s_stats,s_table,s_out_file)
  if (do_se)  call write_verif_ascii_file(se_stats,se_table,se_out_file)
  if (do_ne)    call write_verif_ascii_file(ne_stats,ne_table,ne_out_file)
  if (do_n)    call write_verif_ascii_file(n_stats,n_table,n_out_file)
  
  print *, "Program do_verif finished"
  
  !=================================================================================
end program do_verif
