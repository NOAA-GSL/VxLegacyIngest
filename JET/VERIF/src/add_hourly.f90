program add_hourly
  !===============================================================================================
  !
  ! This program adds together hourly precip totals from HRRR, RR, RUC, or NAM models
  !
  ! INPUTS: numHrs, inputStr, outputFileName
  ! 
  ! OUTPUTS: Precip total NetCDF file
  !
  ! Written by: Patrick Hofmann
  ! Last Update: 09 NOV 2011
  !===============================================================================================
  use netcdf
  
  implicit none

  integer, external                   :: iargc
  integer, dimension(20)              :: status
  integer                             :: ncid, nlat, nlon, i, j, nx, ny, ihr, nhr, dhr
  integer                             :: precipVarID, latVarID, lonVarID
  integer                             :: xDimID, yDimID
  character(len=256)                  :: initHr, numHrs, increment, inputStr, is3hrtotals
  character(len=256)                  :: inputFileName, outputFileName
  character(len=2)                    :: int2str, int2str2
  real, dimension(:,:),   allocatable :: tot_precip, lat, lon
  real, dimension(:,:,:), allocatable :: all_precips
  !-----------------------------------------------------------------------------------------------

  if(iargc() == 0) stop 'You must specify number of hourlies, input string, and output file'
  call getarg(1, initHr)
  call getarg(2, numHrs)
  call getarg(3, increment)
  call getarg(4, inputStr)
  call getarg(5, outputFileName)
  call getarg(6, is3hrtotals)

  read(initHr,'(i2)') ihr
  read(numHrs,'(i2)') nhr
  read(increment,'(i2)') dhr

  ! Loop over files, adding them up as you go
  j = 1
  do i=ihr,nhr,dhr
     write(int2str,'(i2.2)') i
     write(int2str2,'(i2.2)') i+3
     if (trim(is3hrtotals) == 'true') then
        inputFileName = trim(inputStr) // '_' // int2str // '-' // int2str2 // '_total.nc'
     else
        inputFileName = trim(inputStr) // '+' // int2str // '.nc'
     endif
     
     print *, 'Reading ', trim(inputFileName)

     ! Open file and read precip field
     status(:)  = nf90_NoErr
     status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
     
     ! Get number of Xs and Ys
     status(2)  = nf90_inq_dimid(ncid,'y',yDimID)
     status(3)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

     status(4)  = nf90_inq_dimid(ncid,'x',xDimID)
     status(5)  = nf90_inquire_dimension(ncid,xDimID,len = nx)
     
     if (i == ihr) then
        allocate(all_precips((nhr-ihr+dhr)/dhr,nx,ny))
        allocate(tot_precip(nx,ny),lat(nx,ny),lon(nx,ny))

        ! Get lats/lons
        status(6) = nf90_inq_varid(ncid,'latitude',latVarID)
        status(7) = nf90_get_var(ncid,latVarID,lat)
        status(8) = nf90_inq_varid(ncid,'longitude',lonVarID)
        status(9) = nf90_get_var(ncid,lonVarID,lon)
     endif
     
     ! Get VarIDs for all needed variables
     status(10) = nf90_inq_varid(ncid,'APCP_surface',precipVarID)
     
     ! Get variable values
     status(11) = nf90_get_var(ncid,precipVarID,all_precips(j,:,:))
     
     if(any(status(:11) /= nf90_NoErr)) stop "Error reading model NetCDF file"
     
     status(1) = nf90_close(ncid)
     
     print *, 'Done reading file #', j
     j = j + 1
     
  end do

  ! Now, sum across precips
  tot_precip = sum(all_precips,DIM=1)

  deallocate(all_precips)

  ! Write output file
  print *, 'Writing: ', trim(outputFileName)
  
  ! Define file and global attributes
  status(:)  = nf90_NoErr
  status(1)  = nf90_create(trim(outputFileName),nf90_clobber,ncid)
  status(2)  = nf90_put_att(ncid,nf90_global,'title',trim(numHrs) // ' Model Precip Total')
    
  ! Define dimension variables
  status(3)  = nf90_def_dim(ncid,'x',size(tot_precip,1),xDimID)
  status(4)  = nf90_def_dim(ncid,'y',size(tot_precip,2),yDimID)
  
  ! Define variables
  status(5)  = nf90_def_var(ncid,'latitude',nf90_double,(/xDimID,yDimID/),latVarID)
  status(6)  = nf90_def_var(ncid,'longitude',nf90_double,(/xDimID,yDimID/),lonVarID)
  status(7)  = nf90_def_var(ncid,'APCP_surface',nf90_float,(/xDimID,yDimID/),precipVarID)
  status(8)  = nf90_put_att(ncid,precipVarID,'Units','kg/m^2')
  status(9)  = nf90_put_att(ncid,precipVarID,'_FillValue',real(9.999e20))
  
  ! End of definitions
  status(10) = nf90_enddef(ncid)
  
  ! Put dimension variables and state variables
  status(11) = nf90_put_var(ncid,latVarID,lat)
  status(12) = nf90_put_var(ncid,lonVarID,lon)
  status(13) = nf90_put_var(ncid,precipVarID,tot_precip)
  
  if(any(status(:20) /= nf90_NoErr)) stop "Error writing precip totals to NetCDF file"
  
  status(1) = nf90_close(ncid)
  
  print *, 'add_hourly finished'
  
  !===============================================================================================
end program add_hourly
