program prob_interp
!=================================================================================
!
! This program will upscale or downscale as desired to an output grid of choice.
! For the interpolation, NCEP's IPLIB is used.
!
! INPUTS: input namelist, which contains file names and tuning parameters
! 
! OUTPUTS: NetCDF interpolated grids
!
! Written by: Patrick Hofmann
! Last Update: 27 SEP 2011
!
!=================================================================================
use netcdf
use verif_mod

implicit none
integer, external :: iargc

! Define variables
integer                           :: iunit, io

character(len = max_name_len)     :: nml_file, field
                                     
type(state_type)                  :: model_state, interp_model_state,   &
                                     obs_state, interp_obs_state

!---------------------------------------------------------------------------------

! Get namelist file name from command line
if(iargc() == 0) stop "You must specify the namelist file to read and the field name"
call getarg(1,nml_file)
call getarg(2,field)

! Read namelist values
open(unit=5,file=trim(nml_file),action='read')
read(5, nml = main_nml, iostat = io)
if(io /= 0) stop "(MAIN) namelist not opened successfully!"
read(5, nml = interp_nml, iostat = io)
if(io /= 0) stop "(INTERPOLATE) namelist not opened successfully!"
close(5)

if(trim(field) == 'obs') then
   ! Read observation data
   call read_prob_obs_nc_file(obs_grid,obs_nc_var,obs_in_file,mask_file,obs_state)

   ! Interpolate observation data to desired grid
   call interpolate('obs',obs_nc_var,obs_state,interp_obs_state)

   ! Write obs grid to NetCDF file
   call write_interp_state('obs',nc_out_var,interp_grid,obs_out_file,interp_obs_state)
else
   ! Read model data
   call read_prob_model_nc_file(model_nc_var,model_in_file,model_state)

   ! Interpolate model data to desired grid
   call interpolate('model',model_nc_var,model_state,interp_model_state)

   ! Write model grid to NetCDF file
   call write_interp_state('model',nc_out_var,interp_grid,model_out_file,interp_model_state)
endif

print *, "Program cref_interp finished"

!---------------------------------------------------------------------------------

contains

!---------------------------------------------------------------------------------

  subroutine interpolate(switch,var,old_state,interp_state)
    ! Interpolate state to desired grid using specified type of interpolation
    character(len=*), intent(in)      :: switch
    character(len=*), intent(in)      :: var
    type(state_type), intent(inout)   :: old_state
    type(state_type), intent(out)     :: interp_state
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer                              :: iostat
    character(len = max_name_len)        :: old_grid
    integer                              :: ip, km = 1, ibi = 0, ibo, no, func
    integer                              :: status, i, j, k
    integer                              :: xi, yi, mi, xo, yo, mo
    integer, dimension(20)               :: ipopt
    integer, dimension(200)              :: kgdsi, kgdso
    logical, dimension(:,:), allocatable :: lo, li
    real,    dimension(:,:), allocatable :: ro, ri, rtest, lattest,lontest
    real,    dimension(:),   allocatable :: rlat, rlon

 
    print *, 'Interpolating ', switch, ' state'

    if(switch == 'model') then
       old_grid = trim(model_grid)
    else
       old_grid = trim(obs_grid)
    endif

    if(trim(interp_func) == 'average') then
       func = 0
    elseif(trim(interp_func) == 'maxval') then
       func = 1
    else
       stop 'average or maxval for interpolation function, only'
    endif
    
    ! Input GDS parameters
    kgdsi = get_gds(old_grid)
    
    ! Output GDS parameters
    kgdso = get_gds(interp_grid)

    xi = kgdsi(2)
    yi = kgdsi(3)
    xo = kgdso(2)
    yo = kgdso(3)
    mi = xi*yi
    mo = xo*yo

    allocate(li(mi,km),lo(mo,km),ri(mi,km),ro(mo,km),rlat(mo),rlon(mo))
    allocate(interp_state%prob(xo,yo)   , &
             interp_state%missing(xo,yo), &
             interp_state%lat(xo,yo),     &
             interp_state%lon(xo,yo)       )

    if(trim(old_grid) == trim(interp_grid)) then
       interp_state%prob    = old_state%prob
       interp_state%lat     = old_state%lat
       interp_state%lon     = old_state%lon
       interp_state%missing = old_state%missing
    else
       ipopt = interp_opts

       if(trim(interp_method) == 'bilinear') then
          ip = 0
       elseif(trim(interp_method) == 'bicubic') then
          ip = 1
       elseif(trim(interp_method) == 'neighbor') then
          ip = 2
       elseif(trim(interp_method) == 'budget') then
          ip = 3
       elseif(trim(interp_method) == 'spectral') then
          ip = 4
       elseif(trim(interp_method) == 'neighbor-budget') then
          ip = 6
       else
          stop 'Not a recognized interpolation method'
       endif
       
       where(old_state%missing) old_state%prob = -9999.
       
       ri(:,km) = reshape(old_state%prob, (/ size(old_state%prob) /) )
       li(:,km) = 0 
       
       print *, 'Calling ipolates library'
       call ipolates(ip,ipopt,kgdsi,kgdso,mi,mo,km,ibi,li,ri,func,  &
            no,rlat,rlon,ibo,lo,ro,status)
       
       if(status > 0) stop 'Interpolation failed, check input parameters'
       
       interp_state%prob = reshape(ro(:,km), (/ xo,yo /) )
       interp_state%lat  = reshape(rlat,     (/ xo,yo /) )
       interp_state%lon  = reshape(rlon,     (/ xo,yo /) )
       
       if (trim(var) == 'cov_conf') then
          where(interp_state%prob .ge. 3250 .or.  interp_state%prob .le. 1050) interp_state%prob = 33
          where(interp_state%prob .ge. 3150 .and. interp_state%prob .lt. 3250) interp_state%prob = 32
          where(interp_state%prob .ge. 3050 .and. interp_state%prob .lt. 3150) interp_state%prob = 31
          where(interp_state%prob .ge. 2250 .and. interp_state%prob .lt. 3050) interp_state%prob = 23
          where(interp_state%prob .ge. 2150 .and. interp_state%prob .lt. 2250) interp_state%prob = 22
          where(interp_state%prob .ge. 2050 .and. interp_state%prob .lt. 2150) interp_state%prob = 21
          where(interp_state%prob .ge. 1250 .and. interp_state%prob .lt. 2050) interp_state%prob = 13
          where(interp_state%prob .ge. 1150 .and. interp_state%prob .lt. 1250) interp_state%prob = 12
          where(interp_state%prob .ge. 1050 .and. interp_state%prob .lt. 1150) interp_state%prob = 11
       endif

       ! Correctly handle missing values and those outside input grid
       interp_state%missing = .false.
       where(interp_state%prob .lt. 0) interp_state%missing = .true. 
       where(interp_state%prob .lt. 0) interp_state%prob = 0
    endif
    
  end subroutine interpolate

!=================================================================================
end program prob_interp
