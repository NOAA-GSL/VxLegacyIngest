program mk_ce_grid
  !======================================================================================
  !
  ! This program creates an output Cylindrical Equidistant grid based off:
  ! nx,ny,dx,dy,lat0,lon0
  !
  ! Written by: Patrick Hofmann
  ! Last Update: 19 SEP 2011
  !
  !======================================================================================
  use netcdf
  implicit none

  integer                              :: ncid, n, nx, ny
  integer                              :: i, j, k, m
  integer                              :: latVarID, lonVarID, covVarID, confVarID
  integer                              :: xDimID, yDimID, latDimID, lonDimID
  integer, dimension(25)               :: status
  character(len=256)                     :: ff_file
  real                                 :: dy, dx, lat0, lon0
  real,    dimension(:,:), allocatable :: lats, lons
  
  !======================================================================================

  nx = 92
  ny = 46

  dx = 0.76478
  dy = 0.71866
  
  lon0 = 230.019
  lat0 = 20.018

  allocate(lats(nx,ny),lons(nx,ny))
  
  ! Fill lat/lon arrays
  do j=1,ny
     do i=1,nx
        lats(i,j) = lat0 + (j-1)*dy
        lons(i,j) = lon0 + (i-1)*dx
     enddo
  enddo
  
  ! Write output file
  ff_file = 'ncwd_grid_80km.nc'
  print *, 'Writing: ', trim(ff_file)
  
  status(:)  = nf90_NoErr
  status(1)  = nf90_create(trim(ff_file),nf90_clobber,ncid)
  status(2)  = nf90_put_att(ncid,nf90_global,'title','NCWD on 80km grid')
  
  ! Put global attributes from interpolated grid
  status(3)  = nf90_put_att(ncid,nf90_global,'SW_corner_lat',lats(1,1))
  status(4)  = nf90_put_att(ncid,nf90_global,'SW_corner_lon',lons(1,1))
  status(5)  = nf90_put_att(ncid,nf90_global,'NE_corner_lat',lats(nx,ny))
  status(6)  = nf90_put_att(ncid,nf90_global,'NE_corner_lon',lons(nx,ny))
  status(7)  = nf90_put_att(ncid,nf90_global,'MapProjection','CylindricalEquidistant')
  status(8)  = nf90_put_att(ncid,nf90_global,'LatGridSpacing',dy)
  status(9)  = nf90_put_att(ncid,nf90_global,'LonGridSpacing',dx)
  
  ! Define dimension variables
  status(10) = nf90_def_dim(ncid,'x',size(lats,1),xDimID)
  status(11) = nf90_def_dim(ncid,'y',size(lats,2),yDimID)
  
  ! Define variables
  status(12) = nf90_def_var(ncid,'latitude',  nf90_float,(/xDimID,yDimID/),latVarID)
  status(13) = nf90_def_var(ncid,'longitude', nf90_float,(/xDimID,yDimID/),lonVarID)
  
  ! End of definitions
  status(14) = nf90_enddef(ncid)
  
  ! Put dimension variables
  status(15) = nf90_put_var(ncid,latVarID, lats)
  status(16) = nf90_put_var(ncid,lonVarID, lons)
  
  if(any(status(:25) /= nf90_NoErr)) stop "Error writing NCWD data to NetCDF"
  
  status(1) = nf90_close(ncid)
    
  print *, 'mk_ce_grid finished'

end program mk_ce_grid
