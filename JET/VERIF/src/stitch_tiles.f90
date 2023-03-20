program stitch_tiles
  !=================================================================================
  !
  ! This program stitches together the 8 NSSL tiles into one mosaic file
  !
  ! INPUTS: inputDir, outputFileName
  ! 
  ! OUTPUTS: mosaic NetCDF file
  !
  ! Written by: Patrick Hofmann
  ! Last Update: 12MAY2010
  !
  !=================================================================================
  use netcdf

  implicit none

  integer, external      :: iargc
  integer, dimension(20) :: status
  integer                :: ncid, ndims, nvars, natts
  integer                :: nlat, nlon, i
  integer                :: VarID
  integer                :: latDimID, lonDimID
  character(len=256)     :: inputDir, inputFileName, varName, outputFileName
  character(len=256)     :: units
  character(len=1)       :: int2str
  real                   :: scale_fac, missing_val
  real, dimension(:,:), allocatable :: mosaic_var, var

  if(iargc() == 0) stop 'You must specify an input directory, a variable name, and output filename'
  call getarg(1, inputDir)
  call getarg(2, varName)
  call getarg(3, outputFileName)

  allocate(mosaic_var(7001,3501))

  ! Loop over tiles, reading in var from each tile
  do i=1,8
     write(int2str,'(i1)') i
     inputFileName = trim(inputDir) // '/tile_' // int2str // '.nc'

     print *, 'Reading: ', trim(inputFileName)

     ! Open file and read var field
     status(:)  = nf90_NoErr
     status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
     status(2)  = nf90_inquire(ncid,ndims,nvars,natts)
     
     ! Get number of Lats/Lons
     status(3)  = nf90_inq_dimid(ncid,'Lat',latDimID)
     status(4)  = nf90_inquire_dimension(ncid,latDimID,len = nlat)

     status(5)  = nf90_inq_dimid(ncid,'Lon',lonDimID)
     status(6)  = nf90_inquire_dimension(ncid,lonDimID,len = nlon)

     allocate(var(nlon,nlat))
     
     ! Get VarIDs for all needed variables
     status(7)  = nf90_inq_varid(ncid,trim(varName),VarID)
     
     ! Get variable values
     status(8)  = nf90_get_var(ncid,VarID,var)
     
     ! Get variable attributes
     status(9)  = nf90_get_att(ncid,VarID,"Units",units)
     status(10) = nf90_get_att(ncid,VarID,"Scale",scale_fac)
     status(11) = nf90_get_att(ncid,VarID,"MissingData",missing_val)
       
     if(any(status(:11) /= nf90_NoErr)) stop "Error reading model NetCDF file"
     
     status(1) = nf90_close(ncid)
     
     print *, 'Done reading tile ', i
     
     ! Correctly splice tiles together
     if(i == 1) mosaic_var(1:2000,   1:1500)    = var(:,:)
     if(i == 2) mosaic_var(2001:4000,1:1500)    = var(:,:)
     if(i == 3) mosaic_var(4001:5000,1:1500)    = var(:,:)
     if(i == 4) mosaic_var(5001:7001,1:1500)    = var(:,:)
     if(i == 5) mosaic_var(1:2000,   1501:3501) = var(:,:)
     if(i == 6) mosaic_var(2001:4000,1501:3501) = var(:,:)
     if(i == 7) mosaic_var(4001:5000,1501:3501) = var(:,:)
     if(i == 8) mosaic_var(5001:7001,1501:3501) = var(:,:)
     
     deallocate(var)
  end do

  ! Reverse latitude dimension
  mosaic_var = mosaic_var(:,ubound(mosaic_var,2):lbound(mosaic_var,2):-1)

  ! Write output file
  outputFileName = trim(inputDir) // '/' // trim(outputFileName)

  print *, trim(outputFileName)
  
  ! Define NSSL file and global attributes
  status(:)  = nf90_NoErr
  status(1)  = nf90_create(trim(outputFileName),nf90_classic_model,ncid)
  status(2)  = nf90_put_att(ncid,nf90_global,'title','NSSL tile mosaic')
  status(3)  = nf90_put_att(ncid,nf90_global,'DataType','LatLonGrid')
  status(4)  = nf90_put_att(ncid,nf90_global,'Latitude',real(20))
  status(5)  = nf90_put_att(ncid,nf90_global,'Longitude',real(-130))
  status(6)  = nf90_put_att(ncid,nf90_global,'LatGridSpacing',real(0.01))
  status(7)  = nf90_put_att(ncid,nf90_global,'LonGridSpacing',real(0.01))
  
  ! Define dimension variables
  status(8)  = nf90_def_dim(ncid,'Lat',size(mosaic_var,2),latDimID)
  status(9)  = nf90_def_dim(ncid,'Lon',size(mosaic_var,1),lonDimID)
  
  ! Define variables
  status(10) = nf90_def_var(ncid,trim(varName),nf90_float,(/lonDimID,latDimID/),VarID)
  status(11) = nf90_put_att(ncid,VarID,'Scale',scale_fac)
  status(12) = nf90_put_att(ncid,VarID,'Units',trim(units))
  status(13) = nf90_put_att(ncid,VarID,'MissingData',missing_val)
  
  ! End of definitions
  status(14) = nf90_enddef(ncid)
  
  ! Put dimension variables and state variables
  status(15) = nf90_put_var(ncid,VarID,mosaic_var)
  
  if(any(status(:20) /= nf90_NoErr)) stop "Error writing interpolated states to NetCDF file"
  
  status(1) = nf90_close(ncid)
  
  print *, 'stitch_tiles finished'
  
  !===============================================================================================
end program stitch_tiles
