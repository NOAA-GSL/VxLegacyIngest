program prepbufr2txt
!   
!
!
   use kinds, only : r_kind,r_single,len_sta_name
   use module_prepbufr, only :  read_prepbufr
   use module_obs_conv_pt, only :  obs_conv_pt
   use module_time, only :  mtime

   implicit none

   type(read_prepbufr) :: obsall
   type(mtime) :: tm

   integer :: obsdate,obsmin
   character(len=180) :: obsPath,obsfilename
   character(len=180) :: savePath,prefixobssavename
   character(len=180) :: fcstPath,fcstfilename
   character(len=180) :: prefixfcstobssavename
   namelist/setup/ obsdate,obsmin,obsPath,obsfilename,&
                   savePath,prefixobssavename,prefixfcstobssavename,&
                   fcstPath,fcstfilename

   integer :: numobstype
   integer :: obstype(100)
   real(r_single) :: timewindow(100)
   namelist/obsset/ numobstype,obstype,timewindow

   character(len=180) :: obsfile
   character(len=180) :: savefile
   character(len=180) :: savefile_txt
   integer :: n
!
!
!
   obsdate=2017010103
   obsmin=0
   obsPath='../'
   obsfilename='prepbufr'
   savePath='./'
   prefixobssavename='prepbufr'
   prefixfcstobssavename='prepbufr'
   fcstPath='./'
   fcstfilename='wrfout_d01'
   numobstype=1
   obstype=120
   timewindow=1.0

   open(15,file='namelist.input')
   read(15,setup)
   read(15,obsset)
   close(15)

!   write(*,setup)
!   write(*,obsset)
  
!
   obsfile=trim(obsPath)//"/"//trim(obsfilename)
   write(*,*) 'read obs from file=',trim(obsfile)
   savefile=trim(savePath)//"/"//trim(prefixobssavename)
   write(*,*) 'save obs to file=',trim(savefile)

!
   do n=1,numobstype
      write(*,*)
      write(*,*) '================================='
      write(*,*) 'process obstype=',obstype(n), &
                 ' with time window=',timewindow(n)
      call obsall%initial_prepbufr(obstype(n),obsdate,obsmin,timewindow(n))

      call obsall%decodeprepbufr_all(trim(obsfile))
      call obsall%listsnd(savefile)
      !call obsall%writept(trim(savefile))
      call obsall%destroy_prepbufr()
   enddo

end program
