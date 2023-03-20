program do_verif_hrrre
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
  character(len = max_name_len)     :: hrrre_domain
!  type(cont_table_type)             :: conus_table, west_table, east_table, ne_table, se_table, &
!                                       ci_table, hwt_table, roc_table
!  type(stats_type)                  :: conus_stats, west_stats, east_stats, ne_stats, se_stats, &
!                                       ci_stats, hwt_stats, roc_stats
  type(cont_table_type)             :: table
  type(stats_type)                  :: stats
  type(state_type)                  :: model_state, obs_state, verif_state
  
  !-------------------------------------------------------------------------------------------
  
  ! Get namelist file name from command line
  if(iargc() == 0) stop "You must specify the namelist file to read"
  call getarg(1,nml_file)
  
  print *, "Namelist file: ", nml_file
  ! Read namelist values
  open(unit=5,file=trim(nml_file),action='read')
  read(5, nml = main_nml,  iostat = io)
  if(io /= 0) stop "(MAIN) main_nml not opened successfully!"
  read(5, nml = verif_hrrre_nml, iostat = io)
  if(io /= 0) stop "(MAIN) verif_hrrre_nml not opened successfully!"
  close(5)
  
  ! Read model data
  call read_model_nc_file(nc_out_var,model_out_file,model_state)
  
  ! Read observation data
  call read_obs_nc_file(nc_out_var,obs_out_file,obs_state)

    print *, "LAT 1,1: ", model_state%lat(1,1) 
  ! Determine the Region and rededine the table and file
    if(model_state%lat(1,1) == 29.119377) then
       hrrre_domain = 'central'
       interp_grid = trim(interp_grid) // '_C'
      ! stat_out_file = trim(stat_out_file) // '_central.txt'
    elseif(model_state%lat(1,1) == 24.039825) then
       hrrre_domain = 'south'
       interp_grid = trim(interp_grid) // '_S'
      ! stat_out_file = trim(stat_out_file) // '_south.txt'
    elseif(model_state%lat(1,1) == 35.248077) then
       hrrre_domain = 'northeast'
       interp_grid = trim(interp_grid) // '_NE'
      ! stat_out_file = trim(stat_out_file) // '_northeast.txt'
    elseif(model_state%lat(1,1) == 25.522041) then
       hrrre_domain = 'southeast'
       interp_grid = trim(interp_grid) // '_SE'
      ! stat_out_file = trim(stat_out_file) // '_southeast.txt'
    elseif(model_state%lat(1,1) == 36.447021) then
       hrrre_domain = 'north'
       interp_grid = trim(interp_grid) // '_N'
      ! stat_out_file = trim(stat_out_file) // '_southeast.txt'
    else
       stop 'Not a recognized region'
    endif

  !  table = trim(domain) // '_' // trim(table)
  !  stats = trim(domain) // '_' // trim(stats)
 
  ! Calculate contingency table
!  if (do_conus) call calc_contingencies(obs_state,model_state,verif_state,threshold,'conus',conus_table)
!  if (do_west)  call calc_contingencies(obs_state,model_state,verif_state,threshold,'west',west_table)
!  if (do_east)  call calc_contingencies(obs_state,model_state,verif_state,threshold,'east',east_table)
!  if (do_ne)    call calc_contingencies(obs_state,model_state,verif_state,threshold,'ne',ne_table)
!  if (do_se)    call calc_contingencies(obs_state,model_state,verif_state,threshold,'se',se_table)
!  if (do_ci)    call calc_contingencies(obs_state,model_state,verif_state,threshold,'ci',ci_table)
!  if (do_hwt)   call calc_contingencies(obs_state,model_state,verif_state,threshold,'hwt',hwt_table)
!  if (do_roc)   call calc_contingencies(obs_state,model_state,verif_state,threshold,'roc',roc_table)
  
  call calc_contingencies(obs_state,model_state,verif_state,threshold,hrrre_domain,table)

  ! Write verification grid to NetCDF file
  call write_interp_state('verif',nc_out_var,interp_grid,verif_out_file,verif_state)
  
  ! Calculate verification statistics
!  if (do_conus) call calc_statistics(conus_table,conus_stats)
!  if (do_west)  call calc_statistics(west_table,west_stats)
!  if (do_east)  call calc_statistics(east_table,east_stats)
!  if (do_ne)    call calc_statistics(ne_table,ne_stats)
!  if (do_se)    call calc_statistics(se_table,se_stats)
!  if (do_ci)    call calc_statistics(ci_table,ci_stats)
!  if (do_hwt)   call calc_statistics(hwt_table,hwt_stats)
!  if (do_roc)   call calc_statistics(roc_table,roc_stats)
 
  call calc_statistics(table,stats)
 
  ! Write summary statistics to ASCII file
!  if (do_conus) call write_verif_ascii_file(conus_stats,conus_table,conus_out_file)
!  if (do_west)  call write_verif_ascii_file(west_stats,west_table,west_out_file)
!  if (do_east)  call write_verif_ascii_file(east_stats,east_table,east_out_file)
!  if (do_ne)    call write_verif_ascii_file(ne_stats,ne_table,ne_out_file)
!  if (do_se)    call write_verif_ascii_file(se_stats,se_table,se_out_file)
!  if (do_ci)    call write_verif_ascii_file(ci_stats,ci_table,ci_out_file)
!  if (do_hwt)   call write_verif_ascii_file(hwt_stats,hwt_table,hwt_out_file)
!  if (do_roc)   call write_verif_ascii_file(roc_stats,roc_table,roc_out_file)

  call write_verif_ascii_file(stats,table,stat_out_file)
  
  print *, "Program do_verif finished"
  
  !=================================================================================
end program do_verif_hrrre
