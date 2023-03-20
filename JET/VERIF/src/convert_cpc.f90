program convert_cpc
  !=================================================================================
  !
  ! This program reads 24h CPC precipitation files, and outputs to a netcdf file,
  ! with grid specifications.
  !
  ! Info from CPC README:
  !  Resolution:  The resolution of the analysis is 0.25 degree longitude by
  !               0.25 degree latitude.
  !
  !  Domain:      The domain of the analysis is (140W-60W, 20N-60N). The first 
  !               grid point is (140W, 20N), the second one is (139.75W, 20N), 
  !               ... , and the last one is (60W, 60N).
  !  Window:      Day 1 analysis is valid for the window from 12Z on day 0 to
  !               12Z on day 1.
  !
  !  Format:      The format is sequential 32-bit IEEE floating point created 
  !               on a big_endian platform (e.g. cray, sun, sgi and hp). 
  !               The undefined (missing) value is 9999.
  !               A sample FORTRAN code to read the daily file can be found in 
  !               this directory ("read.sample.f"). Note: this code only works
  !               on big_endian platform. If you work on a little_endian platform
  !               such as PC with LINUX box, you need to do bytes-swapping.
  !
  ! INPUTS: inputFileName, outputFileName
  ! 
  ! OUTPUTS: output NetCDF file
  !
  ! Written by: Patrick Hofmann
  ! Last Update: 12 OCT 2010
  !
  !=================================================================================
  use netcdf

  integer, external                 :: iargc
  integer, dimension(20)            :: status
  integer                           :: ncid
  integer                           :: nlat, nlon
  integer                           :: pcpVarID
  integer                           :: latDimID, lonDimID
  character(len=256)                :: inputFileName, outputFileName
  character(len=1)                  :: int2str
  real, dimension(:,:), allocatable :: pcp

  if(iargc() == 0) stop 'You must specify an input directory and output filename'
  call getarg(1, inputFileName)
  call getarg(2, outputFileName)

  allocate(pcp(464,224))

  print *, 'Reading: ', trim(inputFileName)
  
  ! Open file and read pcp field
  open(99,file=trim(inputFileName),form='unformatted',access='sequential',status='old')

  read(99) pcp

  close(99)

  ! Write output file

  print *, 'Writing: ', trim(outputFileName)

  where(pcp == -99) pcp = -999
  
  status(:)  = nf90_NoErr
  status(1)  = nf90_create(trim(outputFileName),nf90_clobber,ncid)
  status(2)  = nf90_put_att(ncid,nf90_global,'title','CPC 24h Precip Data')
  status(3)  = nf90_put_att(ncid,nf90_global,'DataType','LatLonGrid')
  status(4)  = nf90_put_att(ncid,nf90_global,'Latitude',real(25.125))
  status(5)  = nf90_put_att(ncid,nf90_global,'Longitude',real(-124.875))
  status(6)  = nf90_put_att(ncid,nf90_global,'LatGridSpacing',real(0.125))
  status(7)  = nf90_put_att(ncid,nf90_global,'LonGridSpacing',real(0.125))
  
  ! Define dimension variables
  status(8)  = nf90_def_dim(ncid,'Lat',size(pcp,2),latDimID)
  status(9)  = nf90_def_dim(ncid,'Lon',size(pcp,1),lonDimID)
  
  ! Define variables
  status(10) = nf90_def_var(ncid,'precip',nf90_float,(/lonDimID,latDimID/),pcpVarID)
!  status(11) = nf90_def_var(ncid,'hgt_mask',nf90_double,(/lonDimID,latDimID/),hgtmVarID)
!  status(12) = nf90_put_att(ncid,hsrhVarID,'Scale',real(1000))
  status(13) = nf90_put_att(ncid,pcpVarID,'Units','inches/day')
  status(14) = nf90_put_att(ncid,pcpVarID,'_FillValue',real(-999))
  
  ! End of definitions
  status(15) = nf90_enddef(ncid)
  
  ! Put dimension variables and state variables
  status(16) = nf90_put_var(ncid,pcpVarID,pcp)
  
  if(any(status(:20) /= nf90_NoErr)) stop "Error writing CPC precip data to NetCDF"
  
  status(1) = nf90_close(ncid)
  
  print *, 'convert_pcp finished'
  
  !===============================================================================================
end program convert_cpc
