program add_pcp
  !=================================================================================
  !
  ! This program adds convective and non-convective precipitation totals from
  ! RUC data
  !
  ! INPUTS: inputFileName
  ! 
  ! OUTPUTS: output file
  !
  ! Written by: Patrick Hofmann
  ! Last Update: 05 OCT 2010
  !
  !=================================================================================
  use netcdf

  integer, external      :: iargc
  integer, dimension(20) :: status
  integer                :: nlat, nlon, i
  integer                :: acpcpVarID, ncpcpVarID, apcpVarID
  integer                :: latDimID, lonDimID
  character(len=256)     :: inputFileName
  
  real, dimension(:,:), allocatable :: acpcp, ncpcp, apcp

  if(iargc() == 0) stop 'You must specify an input filename'
  call getarg(1, inputFileName)

  print *, 'Reading: ', trim(inputFileName)

  ! Open file and read ACPCP and NCPCP
  status(:)  = nf90_NoErr
  status(1)  = nf90_open(trim(inputFileName),nf90_write,ncid)
     
  ! Get number of Lats/Lons
  status(2)  = nf90_inq_dimid(ncid,'y',latDimID)
  status(3)  = nf90_inquire_dimension(ncid,latDimID,len = nlat)

  status(4)  = nf90_inq_dimid(ncid,'x',lonDimID)
  status(5)  = nf90_inquire_dimension(ncid,lonDimID,len = nlon)

  allocate(acpcp(nlon,nlat),ncpcp(nlon,nlat),apcp(nlon,nlat))
  
  ! Get VarIDs for all needed variables
  status(6) = nf90_inq_varid(ncid,'NCPCP_surface',ncpcpVarID)
  status(7) = nf90_inq_varid(ncid,'ACPCP_surface',acpcpVarID)

  ! Get variable values
  status(8) = nf90_get_var(ncid,ncpcpVarID,ncpcp)
  status(9) = nf90_get_var(ncid,acpcpVarID,acpcp)
     
  apcp = ncpcp + acpcp
  where(apcp > 9e20) apcp = 9.999e20

  status(10) = nf90_redef(ncid)

  status(11) = nf90_def_var(ncid,'APCP_surface',nf90_float,(/lonDimID,latDimID/),apcpVarID)
  status(12) = nf90_put_att(ncid,apcpVarID,'_FillValue',9.999e20)
  status(13) = nf90_put_att(ncid,apcpVarID,'units','kg/m^2')

  ! End of definitions
  status(14) = nf90_enddef(ncid)
  
  ! Put dimension variables and state variables
  status(15) = nf90_put_var(ncid,apcpVarID,apcp)

  if(any(status(:15) /= nf90_NoErr)) stop "Error reading model NetCDF file"
     
  status(1) = nf90_close(ncid)
     
  print *, 'adding precips finished'
  
  !===================================================================================
end program add_pcp
