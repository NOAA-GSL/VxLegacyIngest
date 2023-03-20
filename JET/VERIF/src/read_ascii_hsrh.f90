program read_ascii_hsrh
  !=================================================================================
  !
  ! This program stitches together the 8 NSSL ASCII tiles into one mosaic file
  !
  ! INPUTS: inputDir, outputFileName
  ! 
  ! OUTPUTS: mosaic NetCDF file
  !
  ! Written by: Patrick Hofmann
  ! Last Update: 25JUN2010
  !
  !=================================================================================
  use netcdf

  integer, external      :: iargc
  integer, dimension(20) :: status
  integer                :: ncid, ndims, nvars, natts
  integer                :: nlat, nlon, i, j
  integer                :: hsrhVarID, hgtmVarID
  integer                :: latDimID, lonDimID
  character(len=256)     :: inputDir, inputFileName, outputFileName,tmp
  character(len=1)       :: int2str
  real, dimension(:,:), allocatable :: ahsrh, hsrh, hgt_mask

  if(iargc() == 0) stop 'You must specify an input directory and output filename'
  call getarg(1, inputDir)
  call getarg(2, outputFileName)

  allocate(ahsrh(7001,3501),hgt_mask(7001,3501))

  ! Loop over tiles, reading in hsrh from each tile
  do i=1,8
     write(int2str,'(i1)') i
     inputFileName = trim(inputDir) // '/' // 'us_radcov_hagl_tile' // int2str // '.asc'

     print *, 'Reading: ', trim(inputFileName)

     ! Open file and read hsrh field
     open(99,file=trim(inputFileName),form='formatted',access='sequential',status='old')

     ! Read header lines
     read(99,*) tmp, nlon
     read(99,*) tmp, nlat
     
     do j=1,4
        read(99,*) tmp
     enddo

     allocate(hsrh(nlon,nlat))

     ! Read hsrh values
     do j=1,nlat
        read(99,*) hsrh(:,j)
     enddo

     ! Correctly splice tiles together
     if(i == 1) ahsrh(1:2000,   1:1500)    = hsrh(1:2000,1:1500)
     if(i == 2) ahsrh(2001:4000,1:1500)    = hsrh(1:2000,1:1500)
     if(i == 3) ahsrh(4001:5000,1:1500)    = hsrh(1:1000,1:1500)
     if(i == 4) ahsrh(5001:7001,1:1500)    = hsrh(1:2001,1:1500)
     if(i == 5) ahsrh(1:2000,   1501:3501) = hsrh(1:2000,1:2001)
     if(i == 6) ahsrh(2001:4000,1501:3501) = hsrh(1:2000,1:2001)
     if(i == 7) ahsrh(4001:5000,1501:3501) = hsrh(1:1000,1:2001)
     if(i == 8) ahsrh(5001:7001,1501:3501) = hsrh(1:2001,1:2001)

     close(99)

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
  
  !===============================================================================================
end program read_ascii_hsrh
