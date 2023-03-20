program grid_ccfp
  !======================================================================================
  !
  ! This program reads CCFP polygon ascii files, and outputs to a netcdf file,
  ! with grid specifications.
  !
  ! Output Grid: NCWD, ~4km Lat/Lon grid
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
  ! Last Update: 21 MAR 2011
  !
  !======================================================================================
  use netcdf
  implicit none

  integer, external                    :: iargc
  integer                              :: ncid, n, nx, ny, num_x, num_y, xy_max
  integer                              :: cov, conf, grow, top, spd, dir, start_i, stop_i
  integer                              :: h, i, j, k, m, p, a, c, line_seg, below, above
  integer                              :: latVarID, lonVarID, covVarID, confVarID
  integer                              :: xDimID, yDimID, latDimID, lonDimID
  integer, dimension(25)               :: status
  integer, dimension(:,:), allocatable :: covs, confs, temp, mask, new_mask
  
  real                                 :: dy, dx, ya, yb, y, xa, xb, x
  real,    dimension(:),   allocatable :: pt_i, pt_j
  real,    dimension(:,:), allocatable :: pts, lats, lons, loc, vert
  
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

  allocate(mask(nx,ny),new_mask(nx,ny),covs(nx,ny),confs(nx,ny),temp(nx,ny))
  
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
           mask = 0
           new_mask = 0
           a = a + 1
           print *, 'area fcst, processing... ', trim(tmp)
           read(unit=tmp,fmt=*) area, cov, conf, grow, top, spd, dir, n
           print *, n
           if (n .ne. 38) then
              continue
           else 
              
           ! pts(1,:) are latitudes, pts(2,:) are longitudes
           allocate(pts(2,n))
           allocate(vert(2,n))
           vert = 0
           read(unit=tmp,fmt=*) area, cov, conf, grow, top, spd, dir, n, pts(:,:)

           ! Loop over polygon line segments
           k = 1
           do while(k<n)
              ! Ensure that step size is <= dy
              num_x = ceiling(abs(pts(2,k+1) - pts(2,k))/(10.*dy))
              num_y = ceiling(abs(pts(1,k+1) - pts(1,k))/(10.*dy))
              
              xy_max = max(num_x,num_y)
              
              allocate(loc(2,xy_max),pt_i(xy_max),pt_j(xy_max))

              ! Assign beginning and end points for linear interpolation of line segment
              if (num_x >= num_y) then
                 ya = pts(1,k)/10.
                 yb = pts(1,k+1)/10.
                 xa = pts(2,k)/-10.
                 xb = pts(2,k+1)/-10.
              else
                 ya = pts(2,k)/-10.
                 yb = pts(2,k+1)/-10.
                 xa = pts(1,k)/10.
                 xb = pts(1,k+1)/10.
              endif

              ! Interpolate array of points along line segment
              x = xa
              do m=1,xy_max
                 y = lin_interp(ya,yb,xa,xb,x)
                 if (num_x >= num_y) then
                    loc(:,m) = (/ y, x /)
                 else
                    loc(:,m) = (/ x, y /)
                 endif
                 x = x + (xb-xa)/real(xy_max)
              enddo
              
              ! Determine NCWD gridpoint that line segment lies in
              do m=1,xy_max
                 do j=1,ny
                    if (loc(1,m) >= lats(1,j)-dy/2. .and. loc(1,m) < lats(1,j)+dy/2.) then
                       pt_j(m) = j
                    endif
                 enddo
                 do i=1,nx
                    if (360+loc(2,m) >= lons(i,1)-dx/2. .and. 360+loc(2,m) < lons(i,1)+dx/2.) then
                       pt_i(m) = i
                    endif
                 enddo
              enddo

              ! Assign gridpoints in CCFP line segment to mask
              do m=1,xy_max
                 mask(pt_i(m),pt_j(m)) = k
              enddo
              
              ! Assign i,j values of vertices
              vert(1,k) = pt_j(1)
              vert(1,k+1) = pt_j(xy_max)
              vert(2,k) = pt_i(1)
              vert(2,k+1) = pt_i(xy_max)
              k = k + 1
              deallocate(loc,pt_i,pt_j)
           enddo
           deallocate(pts)
         
           
           ! For each row, calculate the number of boundaries you pass through/along
           do j=1,ny
              c = 1
              do i=1,nx
                 if (mask(i,j) .gt. 0) then
                    line_seg = mask(i,j)
                    
                    if (j .eq. vert(1,line_seg-1)) then
                       if (line_seg-1 .eq. 1) then 
                          below = n - 1
                       else
                          below = line_seg - 2
                       endif
                       
                       if (vert(1,below) .ge. vert(1,line_seg-1) .and. vert(1,line_seg) .ge. vert(1,line_seg-1)) then
                          ! don't count
                          
                       elseif (vert(1,below) .le. vert(1,line_seg-1) .and. vert(1,line_seg) .le. vert(1,line_seg-1)) then
                          ! don't count
                       else
                          ! count
                          new_mask(i,j) = c
                       endif

                    elseif (j .eq. vert(1,line_seg)) then
                       if (line_seg .eq. 1) then 
                          below = n
                       else
                          below = line_seg - 1
                       endif
                       
                       if (vert(1,below) .ge. vert(1,line_seg) .and. vert(1,line_seg+1) .ge. vert(1,line_seg)) then
                          ! don't count
                       elseif (vert(1,below) .le. vert(1,line_seg) .and. vert(1,line_seg+1) .le. vert(1,line_seg)) then
                          ! don't count
                       else
                          ! count
                          new_mask(i,j) = c
                       endif

                    elseif (j .eq. vert(1,line_seg+1)) then
                       if (line_seg+1 .eq. n) then 
                          above = 2
                       else
                          above = line_seg + 2
                       endif
                       if (vert(1,line_seg) .ge. vert(1,line_seg+1) .and. vert(1,above) .ge. vert(1,line_seg+1)) then
                          ! don't count
                       elseif (vert(1,line_seg) .le. vert(1,line_seg+1) .and. vert(1,above) .le. vert(1,line_seg+1)) then
                          ! don't count
                       else
                          ! count
                          new_mask(i,j) = c
                       endif

                    else
                       ! Not on a vertex
                       new_mask(i,j) = c
                    endif
                    
                    if (mask(i-1,j) .gt. 0) then
                       new_mask(i,j) = new_mask(i-1,j)
                    else
                       c = c+ 1
                    endif
                 endif
              enddo
           enddo
           !where (mask > 0) new_mask = 1
           ! Fill polygon by looping over lats/lons
           do j=1,ny
              filling = .false.
              do i=1,nx
                 if (filling) then
                    if (mod(new_mask(i,j),2) .eq. 0 .and. new_mask(i,j) .gt. 0) then
                       stop_i = i
                       mask(start_i:stop_i,j) = 1
                       filling = .false.
                    endif
                 else
                    if (mod(new_mask(i,j),2) .eq. 1) then
                       start_i = i
                       filling = .true.
                    endif
                 endif
              enddo
           enddo
           where(mask > 0) mask = 1
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
           !go_ahead = .false.

           deallocate(vert)
           endif
        endif
     enddo

     ! Write output file
     ff_file = trim(outputFileName) // '+' // int2str // '.nc'
     print *, 'Writing: ', trim(ff_file)
     
     status(:)  = nf90_NoErr
     status(1)  = nf90_create(trim(ff_file),nf90_clobber,ncid)
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
     status(22) = nf90_put_var(ncid,covVarID, new_mask)
     status(23) = nf90_put_var(ncid,confVarID,confs)
     status(24) = nf90_put_var(ncid,latVarID, lats)
     status(25) = nf90_put_var(ncid,lonVarID, lons)
     
     if(any(status(:25) /= nf90_NoErr)) stop "Error writing CCFP data to NetCDF"
     
     status(1) = nf90_close(ncid)
  enddo
  
  ! Close file
  close(99)
  
  print *, 'grid_ccfp finished'
  
  !---------------------------------------------------------------------------------
  
contains
  
  !---------------------------------------------------------------------------------
  
  real function lin_interp(y0,y1,x0,x1,xi)
    real, intent(in) :: y0,y1,x0,x1,xi
    
    lin_interp = y0 + (xi-x0) * (y1-y0)/(x1-x0) 
    
  end function lin_interp
  
  !===============================================================================================
end program grid_ccfp
