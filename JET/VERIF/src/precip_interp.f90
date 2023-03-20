program precip_interp
!=================================================================================
!
! This program creates verification statistics, grids, and figures for 
! Precipitation.  The input grid can be LamCon or EquiDistant Cyl,
! and you can upscale or downscale as desired to an output grid of either of
! these two types.  Adding input grids is fairly trivial.  For the interpolation, 
! NCEP's IPLIB is used.
!
! INPUTS: input namelist, which contains file names and tuning parameters
! 
! OUTPUTS: NetCDF interpolated grids
!
! Written by: Patrick Hofmann
! Last Update: 15 OCT 2010
!
!=================================================================================
use netcdf
use verif_mod2

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
   call read_precip_obs_nc_file(obs_grid,obs_nc_var,obs_in_file,mask_file,obs_state)

   ! Interpolate observation data to desired grid
   call interpolate('obs',obs_state,interp_obs_state)

   ! Write obs grid to NetCDF file
   call write_interp_state('obs',nc_out_var,interp_grid,obs_out_file,'inches',interp_obs_state)
else
   ! Read model data
   call read_precip_model_nc_file(model_nc_var,model_in_file,model_state)

   ! Interpolate model data to desired grid
   call interpolate('model',model_state,interp_model_state)

   ! Write model grid to NetCDF file
   call write_interp_state('model',nc_out_var,interp_grid,model_out_file,'inches',interp_model_state)
endif

print *, "Program precip_interp finished"

!---------------------------------------------------------------------------------

contains

!---------------------------------------------------------------------------------

  subroutine interpolate(switch,old_state,interp_state)
    ! Interpolate state to desired grid using specified type of interpolation
    character(len=*), intent(in)      :: switch
    type(state_type), intent(inout)   :: old_state
    type(state_type), intent(out)     :: interp_state
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer                              :: iostat
    character(len = max_name_len)        :: old_grid
    integer                              :: ip, km = 1, ibi = 0, ibo, no, func
    integer                              :: iret, i, j, k
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
    allocate(interp_state%precip(xo,yo)   , &
             interp_state%missing(xo,yo), &
             interp_state%lat(xo,yo),     &
             interp_state%lon(xo,yo)       )

    if(trim(old_grid) == trim(interp_grid)) then
       interp_state%precip  = old_state%precip
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
       
       where(old_state%missing) old_state%precip = -9999.
       
       ri(:,km) = reshape(old_state%precip, (/ size(old_state%precip) /) )
       li(:,km) = 0 

       print *, 'IP: ', ip
       print *, 'IPOPT: ', size(ipopt)
       print *, 'KGDSI: ', size(kgdsi)
       print *, 'KGDSO: ', size(kgdso)
       print *, 'MI: ', mi
       print *, 'MO: ', mo
       print *, 'KM: ', km
       print *, 'IBI: ', ibi
       print *, 'LI: ', size(li)
       print *, 'RI: ', size(ri)
       print *, 'NO: ', no
       print *, 'RLAT: ', size(rlat)
       print *, 'RLON: ', size(rlon)
       print *, 'IBO: ', ibo
       print *, 'LO: ', size(lo)
       print *, 'RO: ', size(ro)
       print *, 'IRET: ', iret
       !print *, 'FUNC ', func
       
       print *, 'Calling ipolates library'
       call IPOLATES(ip,ipopt,kgdsi,kgdso,mi,mo,km,ibi,li,ri,  &
            no,rlat,rlon,ibo,lo,ro,iret)
       
       if(iret > 0) stop 'Interpolation failed, check input parameters'
       
       interp_state%precip = reshape(ro(:,km), (/ xo,yo /) )
       interp_state%lat  = reshape(rlat,     (/ xo,yo /) )
       interp_state%lon  = reshape(rlon,     (/ xo,yo /) )
       
       ! Correctly handle missing values and those outside input grid
       interp_state%missing = .false.
       where(interp_state%precip .eq. -9999.) interp_state%missing = .true. 
    endif
    
  end subroutine interpolate

!=================================================================================
end program precip_interp
