module module_fix_raob_heights
  !
  ! This module uses the hypsometric equation to fill in missing RAOB heights where possible
  ! We integrate both up and down from nearest levels with full data, look at differences in the
  ! two resulting heights, and average them if reasonable.
  !

  use kinds, only: r_kind,r_single,len_sta_name,rmissing
  use module_obs_base, only : obsbase

  implicit none

  contains
    subroutine fill_heights(snd,tot_fillable_heights,tot_bad_heights)
      type(obsbase), pointer, intent(in) :: snd ! a sounding
      integer,intent(inout) :: tot_fillable_heights  ! total number of fillable (ie, with necessary thermo info)
      integer,intent(inout) :: tot_bad_heights ! tot fillable heights that could NOT be filled
      logical :: print_this = .true.
      integer :: numlvl,numvar,k,ntype,j,n_h_diff
      integer :: ip,it,iq,ih,iu,iv,idx,idy,idt
      integer :: PP,TT,TD,HH,WS,WD
      real :: delta_h, h_up, h_down,h_diff,sum_h_diff,sum2_h_diff,std_h_diff,max_h_diff,mean_h_diff
      integer,parameter :: MAX_HEIGHT_DIFF = 20 ! max allowed height diff between extrapolating up, vs extrapolating down
      logical :: bad_level
      !print *, "in fill_heights for this ob"
      ip=1
      it=2
      iq=3
      ih=4
      iu=5
      iv=6
      idx=7
      idy=8
      idt=9
     ! find levels with pressure, height, temp, dewpoint
      numlvl=snd%numlvl
      numvar = snd%numvar
      sum_h_diff = 0
      sum2_h_diff = 0
      max_h_diff = 0
      n_h_diff = 0
      if(.false.) then
         ! clean out the last three items so we can use them temporarily, for debugging
         do k=1,numlvl
            snd%obs((k-1)*numvar+idx) = 0
            snd%obs((k-1)*numvar+idy) = 0
            snd%obs((k-1)*numvar+idt) = -99999
         enddo
      endif
    
       do k=1,numlvl
          bad_level = .false.
          if(snd%obs((k-1)*numvar+ih) < -99998.0 .and. &
              snd%obs((k-1)*numvar+ip) > -99998.0 .and.  snd%obs((k-1)*numvar+it) > -99998.0 .and. &
              snd%obs((k-1)*numvar+iq) > -99998.0 ) then
             tot_fillable_heights = tot_fillable_heights + 1
             ntype = 5;
             PP=int(snd%obs((k-1)*numvar+ip)*10.0)
             TT=int(snd%obs((k-1)*numvar+it)*10.0)
             TD=int(snd%obs((k-1)*numvar+iq)*10.0)
             HH=int(snd%obs((k-1)*numvar+ih))
             WD=int(snd%obs((k-1)*numvar+iu))
             WS=int(snd%obs((k-1)*numvar+iv))
             !print *
             !write(*,'(10I7)') ntype,PP, HH,TT,TD,WD,WS
            
             ! find mandatory level below
             find_below: do j=k-1,1,-1
                if(snd%obs((j-1)*numvar+ip) > -99998.0 .and.  snd%obs((j-1)*numvar+it) > -99998.0 .and. &
                     snd%obs((j-1)*numvar+iq) > -99998.0 .and. snd%obs((j-1)*numvar+ih) > -99998.0) then
                   ! found mand level below
                   ntype = 4;
                   PP=int(snd%obs((j-1)*numvar+ip)*10.0)
                   TT=int(snd%obs((j-1)*numvar+it)*10.0)
                   TD=int(snd%obs((j-1)*numvar+iq)*10.0)
                   HH=int(snd%obs((j-1)*numvar+ih))
                   WD=int(snd%obs((j-1)*numvar+iu))
                   WS=int(snd%obs((j-1)*numvar+iv))
                   print *, "mand below is"
                   write(*,'(10I7)') ntype,PP, HH,TT,TD,WD,WS
                   ! get height for level k
                   delta_h = hypsometric(snd,k,j)
                   h_up = snd%obs((j-1)*numvar+ih) + delta_h
                   exit find_below
                endif
             enddo find_below
              ! find mandatory level above
             find_above: do j=k+1,numlvl
                if(snd%obs((j-1)*numvar+ip) > -99998.0 .and.  snd%obs((j-1)*numvar+it) > -99998.0 .and. &
                     snd%obs((j-1)*numvar+iq) > -99998.0 .and. snd%obs((j-1)*numvar+ih) > -99998.0) then
                   ! found mand level above
                   ntype = 4;
                   PP=int(snd%obs((j-1)*numvar+ip)*10.0)
                   TT=int(snd%obs((j-1)*numvar+it)*10.0)
                   TD=int(snd%obs((j-1)*numvar+iq)*10.0)
                   HH=int(snd%obs((j-1)*numvar+ih))
                   WD=int(snd%obs((j-1)*numvar+iu))
                   WS=int(snd%obs((j-1)*numvar+iv))
                   print *, "mand above is"
                   write(*,'(10I7)') ntype,PP, HH,TT,TD,WD,WS
                   ! get height for level k
                   delta_h = hypsometric(snd,k,j)
                   h_down = snd%obs((j-1)*numvar+ih) + delta_h
                   h_diff = abs(h_up - h_down)
                   print *,'h_up,h_down,h_diff',h_up,h_down,h_diff
                  ! make sure the height isn't above the higher mandatory level
                   if(h_up > snd%obs((j-1)*numvar+ih)) then
                      print *,'ERROR2: h_up > upper mand level: ',h_up ,snd%obs((j-1)*numvar+ih)
                      bad_level = .true.
                   endif
                   if(h_diff> MAX_HEIGHT_DIFF) then
                      print *,"ERROR1: height difference ",h_diff,"too large. Leaving height as 'missing'. Not included in stats"
                      bad_level = .true.
                   endif
                   if(.not. bad_level) then
                      ! correct height, and temporarily leave record of the h_diffs
                      snd%obs((k-1)*numvar+ih) = (h_up+h_down)/2
                      if(h_diff .gt. max_h_diff) max_h_diff = h_diff
                      n_h_diff = n_h_diff+1
                      sum_h_diff = sum_h_diff+h_diff
                      sum2_h_diff = sum2_h_diff +h_diff**2
                   else
                      tot_bad_heights = tot_bad_heights+1
                   endif
                   !snd%obs((k-1)*numvar+idx) = h_up
                   !snd%obs((k-1)*numvar+idy) = h_down
                   !snd%obs((k-1)*numvar+idt) = h_up - h_down
                   exit find_above
                endif
             enddo find_above
          endif
       enddo  ! end loop over number of levels

       mean_h_diff = sum_h_diff/n_h_diff
       std_h_diff = (sum2_h_diff/n_h_diff - mean_h_diff**2)**0.5
       print *,'n,max,mean,std',n_h_diff,max_h_diff,mean_h_diff,std_h_diff
      !
      if(print_this) then
         call snd%listsnd()
      endif
     end subroutine fill_heights

     real function hypsometric(snd,k,j)
       type(obsbase), pointer, intent(in) :: snd ! a sounding
       integer, intent(in) :: k  ! level to have its height filled
       integer, intent(in) :: j ! level with good height, temp, 
       integer :: numvar
       integer :: ip,it,iq,ih,iu,iv,idx,idy,idt
       real :: log_ratio,p1,p2,vp1,vp2,dp1,dp2,t1,t2,svp1,svp2,mr1,mr2,vt1,vt2,vta,delta_h
       real, parameter :: Rd = 286.9968933 ! Gas constant for dry air        J/degree/kg
       real, parameter :: g   = 9.80616 ! Acceleration due to gravity       m/s^2
       real,parameter :: eps = 0.621970585  ! Ratio of the molec. weights of water and dry air
       real,parameter :: tzero = 273.15 ! to convert from Celsius to Kelvin
       ip=1
       it=2
       iq=3
       ih=4
       iu=5
       iv=6
       idx=7
       idy=8
       idt=9
       numvar = snd%numvar
       p1 = snd%obs((j-1)*numvar+ip)
       p2 = snd%obs((k-1)*numvar+ip)
       log_ratio = log(p1/p2)

       ! get mean virtual temperature in layer from dewpoint
       ! variable Q is actualy dewpont in Celsius
       
       ! use Teten's Formula to get vapor pressure
       dp1 = snd%obs((j-1)*numvar+iq)
       dp2 = snd%obs((k-1)*numvar+iq)
       vp1 = 6.11*(10**((7.5*dp1)/(237.3+dp1))) 
       vp2 = 6.11*(10**((7.5*dp2)/(237.3+dp2)))

       ! get saturated vapor pressure (Teten's formula)
       t1 = snd%obs((j-1)*numvar+it)
       t2 = snd%obs((k-1)*numvar+it)
       svp1 = 6.11*(10**((7.5*t1)/(237.3+t1))) 
       svp2 = 6.11*(10**((7.5*t2)/(237.3+t2)))

       ! get mixing ratio
       !mr1 = (eps*vp1)/(p1-(0.378*vp1)) ! Jeff's way -- don't know where the 0.378 came from
       !mr2 = (eps*vp2)/(p1-(0.378*vp2)) ! ditto. new way (below) results in slightly better height agreement
       mr1 = (eps*vp1)/(p1-vp1)
       mr2 = (eps*vp2)/(p1-vp2)

       ! virtual temperature
       !vt1 = (t1+tzero)*(1+(0.6078*sh1)) ! easier to get vt from mixing ratio than from specific humidity
       !vt2 = (t2+tzero)*(1+(0.6078*sh2))
       ! virtual temp from mixing ratio from https://glossary.ametsoc.org/wiki/Virtual_temperature
       vt1 = (t1+tzero)*(1.+mr1/eps)/(1.+mr1)
       vt2 = (t2+tzero)*(1.+mr2/eps)/(1.+mr2)
       ! average
       vta = (vt1+vt2)/2

       ! hypsometric equation
       delta_h = (Rd/g)*log_ratio*vta

       !print *,p1,t1,dp1,vp1,svp1,mr1,sh1,vt1,delta_h
       
       hypsometric = delta_h
     end function hypsometric
      

  end module module_fix_raob_heights 
    
      
   
