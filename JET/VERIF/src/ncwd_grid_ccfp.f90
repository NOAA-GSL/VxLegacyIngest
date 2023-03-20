program grid_ccfp
  !======================================================================================
  !
  ! This program reads CCFP polygon ascii files, and outputs to a netcdf file,
  ! with grid specifications.
  !
  ! Output Grid: NSSL, ~1km Lat/Lon grid
  !
  ! CCFP ASCII Coded Text Product Format:
  !
  ! CCFP ISSUED VALID AREA COVERAGE CONFIDENCE GROWTH TOPS SPEED DIRECTION VERT# LAT[1] LON[1] ... LAT[VERT#] LON[VERT#] LATT LONT
  ! LINE COVERAGE VERT# LAT[1] LON[1] .... LAT[VERT#] LON[VERT#]
  ! CANADA_FLAG {ON/OFF}
  !
  ! INPUTS: inputFileName, outputFileName
  ! 
  ! OUTPUTS: output NetCDF file
  !
  ! Written by: Patrick Hofmann
  ! Last Update: 27 SEP 2013
  !
  !======================================================================================
  use netcdf
  implicit none

  integer, external                    :: iargc
  integer                              :: ncid, n, nx, ny, num_x, num_y
  integer                              :: cov, conf, grow, top, spd, dir, inout
  integer                              :: h, i, j, k, a
  integer                              :: latVarID, lonVarID, covVarID, confVarID
  integer                              :: xDimID, yDimID, latDimID, lonDimID
  integer, dimension(25)               :: status
  integer, dimension(:,:), allocatable :: covs, confs, temp, mask
  
  real                                 :: dy, dx, y, x
  real,    dimension(:,:), allocatable :: lats, lons, pts, vert
  
  character(len=2)                     :: int2str
  character(len=256)                   :: inputFileName, inputGrid, outputFileName
  character(len=512)                   :: tmp, ccfp, issue, valid, area, ff_file
  
  logical                              :: go_ahead, filling
  !======================================================================================

  ! First, read command line arguments, and then NCWD grid file
  if(iargc() == 0) stop 'You must specify an input directory and output filename'
  call getarg(1, inputFileName)
  call getarg(2, inputGrid)
  call getarg(3, outputFileName)

  print *, 'Reading NCWD grid file: ', trim(inputGrid)

  status(:) = nf90_NoErr
  status(1) = nf90_open(trim(inputGrid),nf90_nowrite,ncid)
  
  ! Get number of Lats/Lons
  status(2) = nf90_inq_dimid(ncid,"y",yDimID)
  status(3) = nf90_inquire_dimension(ncid,yDimID,len = ny)
  
  status(4) = nf90_inq_dimid(ncid,"x",xDimID)
  status(5) = nf90_inquire_dimension(ncid,xDimID,len = nx)
  
  allocate(lats(nx,ny),lons(nx,ny))
  
  ! Get Lat and Lon values
  status(6) = nf90_inq_varid(ncid,"latitude",latVarID)
  status(7) = nf90_get_var(ncid,latVarID,lats)
  status(8) = nf90_inq_varid(ncid,"longitude",lonVarID)
  status(9) = nf90_get_var(ncid,lonVarID,lons)
  
  if(any(status(:5) /= nf90_NoErr)) stop "Error reading NCWD grid"
  
  status(1) = nf90_close(ncid)

  dy = lats(1,2) - lats(1,1)
  dx = lons(2,1) - lons(1,1)

  !------------------------------------------------------------------------------------

  allocate(mask(nx,ny),covs(nx,ny),confs(nx,ny),temp(nx,ny))
  
  ! Read CCFP ascii file
  print *, 'Reading CCFP file: ', trim(inputFileName)
  
  ! Open and read CCFP file
  open(99,file=trim(inputFileName),form='formatted',access='sequential',status='old')
  
  ! Loop over 3 forecasts: 2hr, 4hr, 6hr
  do h=2,6,2
     write(int2str,'(i2.2)') h
     covs = 0
     confs = 0
     
     ! Print fcst
     read(99,*) ccfp, issue, valid
     print *, trim(ccfp) , ' issue: ' , trim(issue) , ' valid: ' , trim(valid)
     
     ! Loop over Areas/Lines and CANADA flag
     go_ahead = .true.
     a = 0
     do while(go_ahead)
        read(99,fmt='(a)') tmp
        if (tmp(1:4) .eq. 'CANA') then
           go_ahead = .false.
        elseif (tmp(1:4) .eq. 'LINE') then
           print *, 'line fcst, ignoring...'
           continue
        else
           a = a + 1
           print *, 'area fcst, processing... ', trim(tmp)
           read(unit=tmp,fmt=*) area, cov, conf, grow, top, spd, dir, n

           ! initialize polygon vertices and mask
           allocate(pts(2,n),vert(2,n))
           vert = 0
           mask = 0

           ! pts(1,:) are latitudes, pts(2,:) are longitudes
           read(unit=tmp,fmt=*) area, cov, conf, grow, top, spd, dir, n, pts(:,:)

           ! Loop over polygon line segments
           k = 1
           do while(k .le. n)              
              x = pts(2,k)/-10.
              y = pts(1,k)/10.

              ! Determine NCWD gridpoint that each vertex lies in
              do i=1,nx
                 if (360+x >= lons(i,1)-dx/2. .and. 360+x < lons(i,1)+dx/2.) then
                    vert(2,k) = i
                 endif
              enddo
              do j=1,ny
                 if (y >= lats(1,j)-dy/2. .and. y < lats(1,j)+dy/2.) then
                    vert(1,k) = j
                 endif
              enddo
              k = k + 1
           enddo

           ! Call F77 subroutine - pnpoly, to determine if each point is in the polygon
           do j=1,ny
              do i=1,nx
                 call pnpoly(i*1.0,j*1.0,vert(2,:),vert(1,:),n,inout)
                 if (inout .ge. 0) then
                    mask(i,j) = 1
                 else
                    mask(i,j) = 0
                 endif
              enddo
           enddo
           
           ! Lastly, assign confidence and coverage arrays based off polygon
           ! Make sure that for overlapping polygons, the highest confidence/coverage value is used.
           if(a .eq. 1) then
              covs  = covs + mask*cov
              confs = confs + mask*conf
           else
              continue
              temp = mask * cov
              where (temp .ge. covs .and. covs .ne. 0) temp = 0
              where (covs .ge. temp .and. temp .ne. 0) covs = 0
              covs = covs + temp
              
              temp = mask * conf
              where (temp .ge. confs .and. confs .ne. 0) temp = 0
              where (confs .ge. temp .and. temp .ne. 0) confs = 0
              confs = confs + temp
           endif

           deallocate(vert,pts)
        endif
     enddo

     ! Write output file
     ff_file = trim(outputFileName) // '+' // int2str // '.nc'
     print *, 'Writing: ', trim(ff_file)
     
     status(:)  = nf90_NoErr
     status(1)  = nf90_create(trim(ff_file),nf90_classic_model,ncid)
     status(2)  = nf90_put_att(ncid,nf90_global,'title','CCFP Forecast Polygons')

     ! Put global attributes from interpolated grid
     status(3)  = nf90_put_att(ncid,nf90_global,'SW_corner_lat',lats(1,1))
     status(4)  = nf90_put_att(ncid,nf90_global,'SW_corner_lon',lons(1,1))
     status(5)  = nf90_put_att(ncid,nf90_global,'NE_corner_lat',lats(nx,ny))
     status(6)  = nf90_put_att(ncid,nf90_global,'NE_corner_lon',lons(nx,ny))
     status(7)  = nf90_put_att(ncid,nf90_global,'MapProjection','CylindricalEquidistant')
     status(8)  = nf90_put_att(ncid,nf90_global,'LatGridSpacing',dy)
     status(9)  = nf90_put_att(ncid,nf90_global,'LonGridSpacing',dx)
     
     ! Put in valid, lead, and forecast times for NCL plotting titles
     status(12) = nf90_put_att(ncid,nf90_global,'ValidTime',valid(1:8) // valid(10:11))
     status(13) = nf90_put_att(ncid,nf90_global,'InitialTime',issue(1:8) // issue(10:11))
     status(14) = nf90_put_att(ncid,nf90_global,'ForecastTime',int2str)
    
     ! Define dimension variables
     status(15) = nf90_def_dim(ncid,'x',size(covs,1),xDimID)
     status(16) = nf90_def_dim(ncid,'y',size(covs,2),yDimID)
     
     ! Define variables
     status(17) = nf90_def_var(ncid,'coverage',  nf90_int,  (/xDimID,yDimID/),covVarID)
     status(18) = nf90_def_var(ncid,'confidence',nf90_int,  (/xDimID,yDimID/),confVarID)
     status(19) = nf90_def_var(ncid,'latitude',  nf90_float,(/xDimID,yDimID/),latVarID)
     status(20) = nf90_def_var(ncid,'longitude', nf90_float,(/xDimID,yDimID/),lonVarID)
    
     ! End of definitions
     status(21) = nf90_enddef(ncid)
    
     ! Put dimension variables and state variables
     status(22) = nf90_put_var(ncid,covVarID, covs)
     status(23) = nf90_put_var(ncid,confVarID,confs)
     status(24) = nf90_put_var(ncid,latVarID, lats)
     status(25) = nf90_put_var(ncid,lonVarID, lons)
     
     if(any(status(:25) /= nf90_NoErr)) stop "Error writing CCFP data to NetCDF"
     
     status(1) = nf90_close(ncid)
  enddo
  
  ! Close file
  close(99)
  
  print *, 'grid_ccfp finished'

  !===============================================================================================
end program grid_ccfp
