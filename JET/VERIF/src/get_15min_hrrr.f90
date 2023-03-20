program get_15min_hrrr
  !=================================================================================
  !
  ! This program reads HRRR 15min VIL data for the input forecast lead, and outputs
  ! RADARVIL and RADAR to a new single snapshot time file.
  !
  ! INPUTS: inputDir, outputFileName
  ! 
  ! OUTPUTS:  NetCDF file
  !
  ! Written by: Patrick Hofmann
  ! Last Update: 12AUG2010
  !
  !=================================================================================
  use netcdf

  integer, external      :: iargc
  integer, dimension(20) :: status
  integer                :: ncid, ndims, nvars, natts
  integer                :: i, snapshot, lead
  integer                :: vilVarID, radarvilVarID
  integer                :: yDimID, xDimID, tDimID
  character(len=256)     :: forecastLead, inputFileName, outputFileName
  
  real, dimension(:,:), allocatable :: vil, radarvil
  real, dimension(:,:,:), allocatable :: tmpvil, tmpradarvil

  if(iargc() == 0) stop 'You must specify an input directory and output filename'
  call getarg(1, forecastLead)
  call getarg(2, inputFileName)
  call getarg(3, outputFileName)

  !inputDir = '/home/rtrr/hrrr/2010081106/wrfprd'

  read(forecastLead,'(i2)') lead

  print *, 'Program get_15min_hrrr starting...'

  print *, 'lead ', lead
  
  if (mod(lead,3) == 1) snapshot = 4
  if (mod(lead,3) == 2) snapshot = 8
  if (mod(lead,3) == 0) snapshot = 12
  if (lead == 0) snapshot = 0
  
  print *, 'snapshot ', snapshot
  print *, 'Reading: ', trim(inputFileName)

  ! Open file and read both VIL fields
  status(:)  = nf90_NoErr
  status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
  status(2)  = nf90_inquire(ncid,ndims,nvars,natts)
  
  ! Get number of Lats/Lons
  status(3)  = nf90_inq_dimid(ncid,'south_north',yDimID)
  status(4)  = nf90_inquire_dimension(ncid,yDimID,len = ny)
  
  status(5)  = nf90_inq_dimid(ncid,'west_east',xDimID)
  status(6)  = nf90_inquire_dimension(ncid,xDimID,len = nx)

  status(7)  = nf90_inq_dimid(ncid,'num_snapshots',tDimID)
  status(8)  = nf90_inquire_dimension(ncid,tDimID,len = nt)
  
  allocate(vil(nx,ny),radarvil(nx,ny),tmpvil(nx,ny,nt),tmpradarvil(nx,ny,nt))
  
  ! Get VarIDs for all needed variables
  status(9)  = nf90_inq_varid(ncid,'VIL',vilVarID)
  status(10) = nf90_inq_varid(ncid,'RADARVIL',radarvilVarID)
  
  ! Get variable values
  status(11) = nf90_get_var(ncid,vilVarID,tmpvil)
  status(12) = nf90_get_var(ncid,radarvilVarID,tmpradarvil)
  
  if(any(status(:12) /= nf90_NoErr)) stop "Error reading model NetCDF file"
  
  status(1) = nf90_close(ncid)
  
  print *, 'Done reading ', trim(inputFileName)

  ! Retrieve correct snapshot
  vil      = tmpvil(:,:,snapshot)
  radarvil = tmpradarvil(:,:,snapshot)

  ! Write output file
  print *, 'Writing ', trim(outputFileName)
  
  ! Define HRRR file and global attributes
  status(:)  = nf90_NoErr
  status(1)  = nf90_create(trim(outputFileName),nf90_clobber,ncid)
  status(2)  = nf90_put_att(ncid,nf90_global,'title','HRRR VIL fields')
  status(3)  = nf90_put_att(ncid,nf90_global,'DataType','HRRR Grid')
  status(4)  = nf90_put_att(ncid,nf90_global,'YGridSpacing',real(3000.))
  status(5)  = nf90_put_att(ncid,nf90_global,'XGridSpacing',real(3000.))
  
  ! Define dimension variables
  status(6)  = nf90_def_dim(ncid,'Y',ny,yDimID)
  status(7)  = nf90_def_dim(ncid,'X',nx,xDimID)
  
  ! Define variables
  status(10) = nf90_def_var(ncid,'VIL',nf90_double,(/xDimID,yDimID/),vilVarID)
  status(11) = nf90_put_att(ncid,vilVarID,'Units','kg m-2')
  
  status(12) = nf90_def_var(ncid,'RADARVIL',nf90_double,(/xDimID,yDimID/),radarvilVarID)
  status(13) = nf90_put_att(ncid,radarvilVarID,'Units','kg m-2')

  ! End of definitions
  status(14) = nf90_enddef(ncid)
  
  ! Put dimension variables and state variables
  status(15) = nf90_put_var(ncid,vilVarID,vil)
  status(16) = nf90_put_var(ncid,radarvilVarID,radarvil)
  
  if(any(status(:16) /= nf90_NoErr)) stop 'Error writing VIL fields to NetCDF file'
  
  status(1) = nf90_close(ncid)
  
  print *, 'Program get_15min_hrrr finished.'
  
  !===============================================================================================
end program get_15min_hrrr
