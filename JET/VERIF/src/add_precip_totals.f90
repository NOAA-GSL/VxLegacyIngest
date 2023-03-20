program add_precip_totals
  !===============================================================================================
  !
  ! This program adds together precip totals from RUC or RR model output
  !
  ! INPUTS: numFiles, inputFile1, inputFile2, ..., outputFileName
  ! 
  ! OUTPUTS: Precip total NetCDF file
  !
  ! Written by: Patrick Hofmann
  ! Last Update: 21 OCT 2010
  !===============================================================================================
  use netcdf
  
  implicit none

  integer, external                   :: iargc
  integer, dimension(25)              :: status
  integer                             :: ncid, ncid2, nlat, nlon, i, nf, nx, ny
  integer                             :: precipVarID, latVarID, lonVarID
  integer                             :: xDimID, yDimID
  character(len=256)                  :: numFiles, precipVar, inputFileName, outputFileName
  character(len=2)                    :: int2str
  real, dimension(:,:),   allocatable :: tot_precip, lat, lon
  real, dimension(:,:,:), allocatable :: all_precips
  !-----------------------------------------------------------------------------------------------

  if(iargc() == 0) stop 'You must specify number of files and their names, and output file'
  
  call getarg(1, precipVar)

  call getarg(2, numFiles)
  
  read(numFiles,'(i2)') nf

  ! Loop over files, adding them up as you go
  do i=1,nf
     call getarg(i+2,inputFileName)
     
     print *, 'Reading: ', trim(inputFileName)

     ! Open file and read precip field
     status(:)  = nf90_NoErr
     status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
     
     ! Get number of Xs and Ys
     status(2)  = nf90_inq_dimid(ncid,'y',yDimID)
     status(3)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

     status(4)  = nf90_inq_dimid(ncid,'x',xDimID)
     status(5)  = nf90_inquire_dimension(ncid,xDimID,len = nx)

     if (i == 1) then
        allocate(all_precips(nf,nx,ny))
        allocate(tot_precip(nx,ny),lat(nx,ny),lon(nx,ny))

        ! Get lats/lons
        status(6) = nf90_inq_varid(ncid,'latitude',latVarID)
        status(7) = nf90_get_var(ncid,latVarID,lat)
        status(8) = nf90_inq_varid(ncid,'longitude',lonVarID)
        status(9) = nf90_get_var(ncid,lonVarID,lon)
     endif
     
     ! Get VarIDs for all needed variables
     status(10) = nf90_inq_varid(ncid,trim(precipVar),precipVarID)
    
     ! Get variable values
     status(11) = nf90_get_var(ncid,precipVarID,all_precips(i,:,:))
     print*, status(:11)
     if(any(status(:11) /= nf90_NoErr)) stop "Error reading model NetCDF file"
     
     if (i < nf) status(1) = nf90_close(ncid)
     
     print *, 'Done reading file #', i
     
  end do
  
  call getarg(3+nf, outputFileName)

  ! Now, sum across precips
  tot_precip = sum(all_precips,DIM=1)

  where (tot_precip < 0) tot_precip = -999.

  ! Write output file
  print *, 'Writing: ', trim(outputFileName)
  
  ! Define file and global attributes
  status(:)  = nf90_NoErr
  status(1)  = nf90_create(trim(outputFileName),nf90_clobber,ncid2)
  status(2)  = nf90_put_att(ncid2,nf90_global,'title',trim(numFiles) // ' Model Precip Total')
    
  if (trim(precipVar) == 'precip') then
     status(3)  = nf90_copy_att(ncid,nf90_global,'SW_corner_lat',ncid2,nf90_global)
     status(4)  = nf90_copy_att(ncid,nf90_global,'SW_corner_lon',ncid2,nf90_global)
     status(5)  = nf90_copy_att(ncid,nf90_global,'NE_corner_lat',ncid2,nf90_global)
     status(6)  = nf90_copy_att(ncid,nf90_global,'NE_corner_lon',ncid2,nf90_global)
     status(7)  = nf90_copy_att(ncid,nf90_global,'MapProjection',ncid2,nf90_global)
     status(8)  = nf90_copy_att(ncid,nf90_global,'YGridSpacing',ncid2,nf90_global)
     status(9)  = nf90_copy_att(ncid,nf90_global,'XGridSpacing',ncid2,nf90_global)
     status(10) = nf90_copy_att(ncid,nf90_global,'Standard_lon',ncid2,nf90_global)
     status(11) = nf90_copy_att(ncid,nf90_global,'Standard_lat',ncid2,nf90_global)
     status(12) = nf90_copy_att(ncid,nf90_global,'ValidTime',ncid2,nf90_global)
     status(13) = nf90_close(ncid)
  end if
  
  ! Define dimension variables
  status(14)  = nf90_def_dim(ncid2,'x',size(tot_precip,1),xDimID)
  status(15)  = nf90_def_dim(ncid2,'y',size(tot_precip,2),yDimID)
  
  ! Define variables
  status(16)  = nf90_def_var(ncid2,'latitude',nf90_double,(/xDimID,yDimID/),latVarID)
  status(17)  = nf90_def_var(ncid2,'longitude',nf90_double,(/xDimID,yDimID/),lonVarID)
  status(18)  = nf90_def_var(ncid2,trim(precipVar),nf90_float,(/xDimID,yDimID/),precipVarID)
  status(19)  = nf90_put_att(ncid2,precipVarID,'Units','kg/m^2')
  status(20)  = nf90_put_att(ncid2,precipVarID,'_FillValue',real(-999))
  
  ! End of definitions
  status(21) = nf90_enddef(ncid2)
  
  ! Put dimension variables and state variables
  status(22) = nf90_put_var(ncid2,latVarID,lat)
  status(23) = nf90_put_var(ncid2,lonVarID,lon)
  status(24) = nf90_put_var(ncid2,precipVarID,tot_precip)
  
  if(any(status(:24) /= nf90_NoErr)) stop "Error writing interpolated states to NetCDF file"
  
  status(1) = nf90_close(ncid2)
  
  print *, 'add_precip_totals finished'
  
  !===============================================================================================
end program add_precip_totals
