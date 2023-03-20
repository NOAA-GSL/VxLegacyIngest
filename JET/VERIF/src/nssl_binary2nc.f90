program nssl_binary2nc
  !=================================================================================
  !
  ! This program stitches together the new 4 NSSL tiles into one mosaic file
  !
  ! INPUTS: inputDir, inputFileName, varName, outputFileName
  ! 
  ! OUTPUTS: mosaic NetCDF file
  !
  ! Written by: Patrick Hofmann
  ! Last Update: 08 AUG 2013
  !
  !=================================================================================
  use netcdf

  implicit none

  ! variables for output NetCDF file
  integer, external      :: iargc
  integer, dimension(20) :: status
  integer                :: ncid, ndims, nvars, natts
  integer                :: VarID
  integer                :: latDimID, lonDimID
  character(len=256)     :: inputDir, varName, outputFileName
  character(len=256)     :: infile, outfile, time
  character(len=1)       :: int2str

  ! variables for reading input file
  integer                                 ::ntot, i, j, jrec, m
  logical                                 ::looping
  integer*4                               :: yr,mo,da,hr,mn,sc,nx,ny,nz
  integer*4                               :: nw_lon, nw_lat, dx, dy, dz
  integer*4                               :: map_scale, dxy_scale, z_scale
  integer*4                               :: var_scale, missing_val, numrad
  integer*4                               :: dvals(3), blank(10), temp(42)
  character(len=4)                        :: d_val, rlist
  character(len=6)                        :: var_unit
  character(len=20)                       :: var_name
  integer*2, dimension(:),   allocatable  :: var
  real,      dimension(:,:), allocatable  :: mosaic, tile
  !=================================================================================
  ! BEGIN PROGRAM

  ! Read command-line arguments
  if(iargc() == 0) stop 'You must specify an input directory, a variable name, and output filename'
  call getarg(1, inputDir)
  call getarg(2, varName)
  call getarg(3, outputFileName)

  ! Allocate full CONUS array
  allocate(mosaic(7000,3500))

  ! Loop over tiles, reading in var from each tile
  do i=1,4
     write(int2str,'(i1)') i
     infile = trim(inputDir) // '/tile_' // int2str // '.bin'

     print *, 'Reading: ', trim(infile)

     ! Open and set position to start of file
     open(99,file=trim(infile),form='unformatted',access='direct',recl=6,status='old')
     rewind(99)

     ! Read header data
     read(99,rec=1) yr, mo, da, hr, mn, sc
     read(99,rec=2) nx, ny, nz, d_val, map_scale, dvals(1)
     read(99,rec=3) dvals(2:3),  nw_lon, nw_lat, dvals(4), dx
     read(99,rec=4) dy, dxy_scale, dz, z_scale, blank(1:2)
     read(99,rec=5) blank(3:8)
     read(99,rec=6) blank(9:10), var_name(1:16)
     read(99,rec=7) var_name(17:20), var_unit, var_scale, missing_val, numrad, rlist(1:2)

     ! Allocate 1D and 2D array for tile data
     ntot = nx*ny*nz
     allocate(var(ntot),tile(nx,ny))
     
     ! Read rest of header data and first few tile data values
     read(99,rec=8) rlist(3:4), var(1:11)
     
     ! Print header data
     print *, "Year Month Day Hour Min Sec: ", yr, mo, da, hr, mn, sc
     print *, "nx, ny, nz: ", nx, ny, nz
     print *, "d_val, dvals: ", d_val, dvals
     print *, "nw_lon, nw_lat: ", nw_lon, nw_lat
     print *, "dx, dy, dz: ", dx, dy, dz
     print *, "map_scale, dxy_scale, z_scale:", map_scale, dxy_scale, z_scale
     print *, "blank:", blank
     print *, "var_name, var_unit:", var_name, ' ', var_unit
     print *, "var_scale, missing_val, numrad, rlist:", var_scale, missing_val, numrad, rlist

     ! Clunkily read 12 values at a time (ugh)
     j=0
     jrec=9
     looping = .True.
     do while(looping)
        if (23+j > ntot) then
           read(99,rec=jrec) var(12+j:ntot)
           looping = .False.
        else
           read(99,rec=jrec) var(12+j:23+j)
        endif
        jrec = jrec + 1
        j = j+12
     enddo
        
     close(99)

     ! Transform into 2D array
     do m=1,ny
        tile(:,m) = var((m-1)*nx+1:(m-1)*nx+nx)
     enddo

     ! Fill relevant portion of CONUS matrix with tile
     if (i == 1) mosaic(1:3500,1751:3500) = tile
     if (i == 2) mosaic(3501:7000,1751:3500) = tile
     if (i == 3) mosaic(1:3500,1:1750) = tile
     if (i == 4) mosaic(3501:7000,1:1750) = tile
    
     deallocate(var,tile)
  enddo

  ! Create date string
  write(time,'(i4,i0.2,i0.2,i0.2)') yr, mo, da, hr

  ! Correctly differentiate between missing values and zeros
  where(mosaic == missing_val*var_scale) mosaic = 0
  where(mosaic == -9990) mosaic = missing_val*var_scale
  
  !---------------------------------------------------------------------------------
  
  ! Write output file
  outfile = trim(inputDir) // '/' // trim(outputFileName)

  print *, trim(outfile)
  
  ! Define NSSL file and global attributes
  status(:)  = nf90_NoErr
  status(1)  = nf90_create(trim(outfile),nf90_classic_model,ncid)
  status(2)  = nf90_put_att(ncid,nf90_global,'title','NSSL tile mosaic')
  status(3)  = nf90_put_att(ncid,nf90_global,'DataType','LatLonGrid')
  status(4)  = nf90_put_att(ncid,nf90_global,'Latitude',real(20))
  status(5)  = nf90_put_att(ncid,nf90_global,'Longitude',real(-130))
  status(6)  = nf90_put_att(ncid,nf90_global,'LatGridSpacing',real(0.01))
  status(7)  = nf90_put_att(ncid,nf90_global,'LonGridSpacing',real(0.01))
  status(8)  = nf90_put_att(ncid,nf90_global,'validTime',trim(time))
  
  ! Define dimension variables
  status(9)  = nf90_def_dim(ncid,'Lat',size(mosaic,2),latDimID)
  status(10) = nf90_def_dim(ncid,'Lon',size(mosaic,1),lonDimID)

  ! Define variables
  status(11) = nf90_def_var(ncid,trim(varName),nf90_float,(/lonDimID,latDimID/),VarID)
  status(12) = nf90_put_att(ncid,VarID,'Scale',var_scale)
  status(13) = nf90_put_att(ncid,VarID,'Units',trim(var_unit))
  status(14) = nf90_put_att(ncid,VarID,'_FillValue',float(missing_val*var_scale))
  
  ! End of definitions
  status(15) = nf90_enddef(ncid)
  
  ! Put dimension variables and state variables
  status(16) = nf90_put_var(ncid,VarID,mosaic)

  if(any(status(:20) /= nf90_NoErr)) stop "Error writing interpolated states to NetCDF file"
  
  status(1) = nf90_close(ncid)
  
  print *, 'program nssl_binary2nc finished'
  
  !===============================================================================================
end program  nssl_binary2nc
