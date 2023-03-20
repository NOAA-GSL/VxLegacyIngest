program stitch_hsrh
  !=================================================================================
  !
  ! This program stitches together the 8 HSRH NSSL tiles into one mosaic file
  !
  ! INPUTS: inputDir, outputFileName
  ! 
  ! OUTPUTS: mosaic NetCDF file
  !
  ! Written by: Patrick Hofmann
  ! Last Update: 16JUN2010
  !
  !=================================================================================
  use netcdf

  integer, external      :: iargc
  integer, dimension(20) :: status
  integer                :: ncid, ndims, nvars, natts
  integer                :: nlat, nlon, i
  integer                :: hsrhVarID, hgtmVarID
  integer                :: latDimID, lonDimID
  character(len=256)     :: inputDir, inputFileName, outputFileName
  character(len=1)       :: int2str
  real, dimension(:,:), allocatable :: ahsrh, hsrh, hgt_mask

  if(iargc() == 0) stop 'You must specify an input directory and output filename'
  call getarg(1, inputDir)
  call getarg(2, outputFileName)

  !inputDir = '/lfs0/projects/wrfruc/phofmann/radar_verif/data/NSSL/2009072915'

  allocate(ahsrh(7001,3501),hgt_mask(7001,3501))

  ! Loop over tiles, reading in hsrh from each tile
  do i=1,8
     write(int2str,'(i1)') i
     inputFileName = trim(inputDir) // '/tile_' // int2str // '.nc'

     print *, 'Reading: ', trim(inputFileName)

     ! Open file and read hsrh field
     status(:)  = nf90_NoErr
     status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
     status(2)  = nf90_inquire(ncid,ndims,nvars,natts)
     
     ! Get number of Lats/Lons
     status(3)  = nf90_inq_dimid(ncid,'Lat',latDimID)
     status(4)  = nf90_inquire_dimension(ncid,latDimID,len = nlat)

     status(5)  = nf90_inq_dimid(ncid,'Lon',lonDimID)
     status(6)  = nf90_inquire_dimension(ncid,lonDimID,len = nlon)

     allocate(hsrh(nlon,nlat))
     
     ! Get VarIDs for all needed variables
     status(7) = nf90_inq_varid(ncid,'hsrh',hsrhVarID)
     
     ! Get variable values
     status(8) = nf90_get_var(ncid,hsrhVarID,hsrh)
     
     if(any(status(:8) /= nf90_NoErr)) stop "Error reading model NetCDF file"
     
     status(1) = nf90_close(ncid)
     
     print *, 'Done reading tile ', i
     
     ! Correctly splice tiles together
     if(i == 1) ahsrh(1:2000,   1:1500)    = hsrh(:,:)
     if(i == 2) ahsrh(2001:4000,1:1500)    = hsrh(:,:)
     if(i == 3) ahsrh(4001:5000,1:1500)    = hsrh(:,:)
     if(i == 4) ahsrh(5001:7001,1:1500)    = hsrh(:,:)
     if(i == 5) ahsrh(1:2000,   1501:3501) = hsrh(:,:)
     if(i == 6) ahsrh(2001:4000,1501:3501) = hsrh(:,:)
     if(i == 7) ahsrh(4001:5000,1501:3501) = hsrh(:,:)
     if(i == 8) ahsrh(5001:7001,1501:3501) = hsrh(:,:)
     
     deallocate(hsrh)
  end do

  ! Reverse latitude dimension
  ahsrh = ahsrh(:,ubound(ahsrh,2):lbound(ahsrh,2):-1)

  ! Write output file
  outputFileName = trim(inputDir) // '/' // trim(outputFileName)

  print *, trim(outputFileName)

  where(ahsrh >  3500) hgt_mask = 0
  where(ahsrh <= 3500) hgt_mask = 1
  where(ahsrh < 0) hgt_mask = 0
  
  ! Define NSSL file and global attributes
  status(:)  = nf90_NoErr
  status(1)  = nf90_create(trim(outputFileName),nf90_clobber,ncid)
  status(2)  = nf90_put_att(ncid,nf90_global,'title','NSSL tile mosaic')
  status(3)  = nf90_put_att(ncid,nf90_global,'DataType','LatLonGrid')
  status(4)  = nf90_put_att(ncid,nf90_global,'Latitude',real(20))
  status(5)  = nf90_put_att(ncid,nf90_global,'Longitude',real(-130))
  status(6)  = nf90_put_att(ncid,nf90_global,'LatGridSpacing',real(0.01))
  status(7)  = nf90_put_att(ncid,nf90_global,'LonGridSpacing',real(0.01))
  
  ! Define dimension variables
  status(8)  = nf90_def_dim(ncid,'Lat',size(ahsrh,2),latDimID)
  status(9)  = nf90_def_dim(ncid,'Lon',size(ahsrh,1),lonDimID)
  
  ! Define variables
  status(10) = nf90_def_var(ncid,'hsrh',nf90_double,(/lonDimID,latDimID/),hsrhVarID)
  status(11) = nf90_def_var(ncid,'hgt_mask',nf90_double,(/lonDimID,latDimID/),hgtmVarID)
  status(12) = nf90_put_att(ncid,hsrhVarID,'Scale',real(1000))
  status(13) = nf90_put_att(ncid,hsrhVarID,'Units','dBZ')
  status(14) = nf90_put_att(ncid,hsrhVarID,'MissingData',real(-1))
  
  ! End of definitions
  status(15) = nf90_enddef(ncid)
  
  ! Put dimension variables and state variables
  status(16) = nf90_put_var(ncid,hsrhVarID,ahsrh)
  status(16) = nf90_put_var(ncid,hgtmVarID,hgt_mask)
  
  if(any(status(:20) /= nf90_NoErr)) stop "Error writing interpolated states to NetCDF file"
  
  status(1) = nf90_close(ncid)
  
  print *, 'stitch_tiles finished'
  
  !===============================================================================================
end program stitch_hsrh
