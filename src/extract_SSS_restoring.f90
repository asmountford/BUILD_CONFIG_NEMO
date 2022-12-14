program modif                                         
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
! Used to build netcdf files with sea surface salinity (used for restoring)
!
! 0- Initialiartions
! 1- Read information on grids
! 2- Read child mask
! 3- Read input file dimensions in first existing file for specified time window
!    (can be 2d or 3d salinity)
! 4- Process all gridT files over specified period
!
! history : - Jan. 2015: initial version (N. Jourdain, CNRS-LGGE)
!           - Feb. 2017: version with namelist (N. Jourdain, CNRS-IGE)
!           - Jan. 2022: cleaning and new naming convention (PAR/EXT/CHLD)
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
USE netcdf                                            

use gsw_mod_kinds
use gsw_mod_netcdf
use gsw_mod_toolbox

use gsw_mod_error_functions, only : gsw_error_code, gsw_error_limit

IMPLICIT NONE                                         

!-- namelist parameters :
namelist /general/ config, config_dir
namelist /sss_resto/ nn_sss_yeari, nn_sss_yearf, sss_dir, sss_prefix, nn_sss_eosmatch, &
&                    sss_suffix, file_sss_mask, sss_sep1, sss_sep2
CHARACTER(LEN=50)                    :: config, sss_sep1, sss_sep2
CHARACTER(LEN=150)                   :: config_dir, sss_dir, sss_prefix, sss_suffix, file_sss_mask
INTEGER                              :: nn_sss_yeari, nn_sss_yearf, nn_sss_eosmatch

INTEGER                              :: status, mtime, dimID_x, dimID_y, mx_PAR, my_PAR, kday, kmonth, kyear,   &
&                                       vosaline_ID, time_counter_ID, nav_lon_ID, nav_lat_ID, fidSSS, mz,   &
&                                       dimID_time_counter, time_ID, dimID_time, fidS, ai, aj, bi, bj, kfmt,&
&                                       i, j, k, l, fidC, imin_EXT, jmin_EXT, iPAR, jPAR, dimID_z,    &
&                                       nfmt, lon_ID, lat_ID, iCHLD, jCHLD, tmask_PAR_ID, ntest, ntest2,      &
&                                       fidMSKCHLD, mx_CHLD, my_CHLD, mz_CHLD, fidMSKIN, tmask_CHLD_ID, iii, jjj,&
&                                       kiter, rs, dij, im1, ip1, jm1, jp1, fidM, mz_PAR, nntrp
CHARACTER(LEN=100)                           :: calendar, time_units
CHARACTER(LEN=150)                           :: file_coord, file_in_SSS, file_CHLD_SSS, file_in_mask_CHLD, &
&                                               file_in_coord_CHLD, file_in_gridS, command_str
INTEGER(KIND=4),ALLOCATABLE,DIMENSION(:)     :: list_fmt
INTEGER(KIND=1),ALLOCATABLE,DIMENSION(:,:)   :: tmask_PAR, tmask_CHLD, missing, tmp_missing
INTEGER(KIND=1),ALLOCATABLE,DIMENSION(:,:,:) :: tmask
REAL(KIND=4),ALLOCATABLE,DIMENSION(:,:)      :: nav_lon, nav_lat, nav_lon_CHLD, nav_lat_CHLD
REAL(KIND=8),ALLOCATABLE,DIMENSION(:,:,:)    :: vosaline_PAR, vosaline_CHLD, tmp_vosaline_CHLD
REAL(KIND=4),ALLOCATABLE,DIMENSION(:,:,:,:)  :: vosaline_3d
REAL(KIND=8),ALLOCATABLE,DIMENSION(:)        :: time
LOGICAL                                      :: existfile, ln_2d, iout, ll_climato

!=================================================================================
!- 0- Initialiartions
!=================================================================================

call gsw_saar_init (.true.)

write(*,*) 'Reading namelist parameters'

! Default values (replaced with namelist values if specified):
config_dir        = '.'
nn_sss_eosmatch   =   1

!- read namelist values :
OPEN (UNIT=1, FILE='namelist_pre' )
READ (UNIT=1, NML=general)
READ (UNIT=1, NML=sss_resto)
CLOSE(1)

!- name of child domain coordinates (input) :
write(file_in_coord_CHLD,103) TRIM(config_dir), TRIM(config)
103 FORMAT(a,'/coordinates_',a,'.nc')

!- name of child domain mesh_mask (input) :
write(file_in_mask_CHLD,101) TRIM(config_dir), TRIM(config)
101 FORMAT(a,'/mesh_mask_',a,'.nc')

!=================================================================================
! 1- Read information on grids
!=================================================================================

!- Read global attributes of coordinate file to get grid correspondance :
!       i_EXT = ai * i_PAR + bi
!       j_EXT = aj * j_PAR + bj

write(*,*) 'Reading parameters for grid correspondence in the attributes of ', TRIM(file_in_coord_CHLD)
status = NF90_OPEN(TRIM(file_in_coord_CHLD),0,fidC); call erreur(status,.TRUE.,"read global grid coord input")
status = NF90_GET_ATT(fidC, NF90_GLOBAL, "ai", ai); call erreur(status,.TRUE.,"read att1")
status = NF90_GET_ATT(fidC, NF90_GLOBAL, "bi", bi); call erreur(status,.TRUE.,"read att2")
status = NF90_GET_ATT(fidC, NF90_GLOBAL, "aj", aj); call erreur(status,.TRUE.,"read att3")
status = NF90_GET_ATT(fidC, NF90_GLOBAL, "bj", bj); call erreur(status,.TRUE.,"read att4")
status = NF90_GET_ATT(fidC, NF90_GLOBAL, "imin_extraction", imin_EXT); call erreur(status,.TRUE.,"read att5")
status = NF90_GET_ATT(fidC, NF90_GLOBAL, "jmin_extraction", jmin_EXT); call erreur(status,.TRUE.,"read att6")
status = NF90_CLOSE(fidC)                         ; call erreur(status,.TRUE.,"end read fidC")

!=================================================================================
! 2- Read child mask (CHLD) :
!=================================================================================

write(*,*) 'Reading child mask in ', TRIM(file_in_mask_CHLD)
status = NF90_OPEN(TRIM(file_in_mask_CHLD),0,fidMSKCHLD); call erreur(status,.TRUE.,"read child mask") 
!-
status = NF90_INQ_DIMID(fidMSKCHLD,"z",dimID_z)
if ( status .ne. 0 ) status = NF90_INQ_DIMID(fidMSKCHLD,"nav_lev",dimID_z)
call erreur(status,.TRUE.,"inq_dimID_z_CHLD")
status = NF90_INQ_DIMID(fidMSKCHLD,"y",dimID_y); call erreur(status,.TRUE.,"inq_dimID_y_CHLD")
status = NF90_INQ_DIMID(fidMSKCHLD,"x",dimID_x); call erreur(status,.TRUE.,"inq_dimID_x_CHLD")
!-
status = NF90_INQUIRE_DIMENSION(fidMSKCHLD,dimID_z,len=mz_CHLD); call erreur(status,.TRUE.,"inq_dim_z_CHLD")
status = NF90_INQUIRE_DIMENSION(fidMSKCHLD,dimID_y,len=my_CHLD); call erreur(status,.TRUE.,"inq_dim_y_CHLD")
status = NF90_INQUIRE_DIMENSION(fidMSKCHLD,dimID_x,len=mx_CHLD); call erreur(status,.TRUE.,"inq_dim_x_CHLD")
!-
ALLOCATE(  tmask(mx_CHLD,my_CHLD,mz_CHLD), tmask_CHLD(mx_CHLD,my_CHLD)  ) 
status = NF90_INQ_VARID(fidMSKCHLD,"tmask",tmask_CHLD_ID) ; call erreur(status,.TRUE.,"inq_tmask_CHLD_ID")
status = NF90_GET_VAR(fidMSKCHLD,tmask_CHLD_ID,tmask)     ; call erreur(status,.TRUE.,"getvar_tmask_CHLD")
tmask_CHLD(:,:)=tmask(:,:,1)
DEALLOCATE(tmask)
!-
status = NF90_CLOSE(fidMSKCHLD); call erreur(status,.TRUE.,"end read fidMSKCHLD")

!=================================================================================
! 3- Read input file dimensions in first existing file for specified time window
!=================================================================================

!- accepted input format :
191 FORMAT(a,'/',i4.4,'/',a,i4.4,a,i2.2,a,i2.2,a,'.nc')  ! <sss_dir>/YYYY/<sss_prefix>YYYY<sss_sep1>MM<sss_sep2>DD<sss_suffix>.nc  
192 FORMAT(a,'/',i4.4,'/',a,i4.4,a,i2.2,a,'.nc')         ! <sss_dir>/YYYY/<sss_prefix>YYYY<sss_sep1>MM<sss_suffix>.nc  
193 FORMAT(a,'/',a,i4.4,a,i2.2,a,i2.2,a,'.nc')           ! <sss_dir>/<sss_prefix>YYYY<sss_sep1>MM<sss_sep2>DD<sss_suffix>.nc  
194 FORMAT(a,'/',a,i4.4,a,i2.2,a,'.nc')                  ! <sss_dir>/<sss_prefix>YYYY<sss_sep1>MM<sss_suffix>.nc 
195 FORMAT(a,'/',a,'.nc')                                ! <sss_dir>/<sss_prefix>.nc

ALLOCATE(list_fmt(5))
list_fmt=(/191,192,193,194,195/)

ll_climato = .false.

kyear=nn_sss_yeari
kmonth=1
DO kday=1,31

  do kfmt=1,size(list_fmt)
     nfmt=list_fmt(kfmt)
     SELECT CASE(nfmt)
        CASE(191)
          write(file_in_SSS,191) TRIM(sss_dir), kyear, TRIM(sss_prefix), kyear, TRIM(sss_sep1), kmonth, TRIM(sss_sep2), kday, TRIM(sss_suffix)
        CASE(192)
          write(file_in_SSS,192) TRIM(sss_dir), kyear, TRIM(sss_prefix), kyear, TRIM(sss_sep1), kmonth, TRIM(sss_suffix) 
        CASE(193)
          write(file_in_SSS,193) TRIM(sss_dir), TRIM(sss_prefix), kyear, TRIM(sss_sep1), kmonth, TRIM(sss_sep2), kday, TRIM(sss_suffix)
        CASE(194)
          write(file_in_SSS,194) TRIM(sss_dir), TRIM(sss_prefix), kyear, TRIM(sss_sep1), kmonth, TRIM(sss_suffix)
        CASE(195)
          write(file_in_SSS,195) TRIM(sss_dir), TRIM(sss_prefix)
          ll_climato = .true.
        CASE DEFAULT 
          write(*,*) 'wrong nfmt value >>>>>> stop !'
          stop
     END SELECT
     write(*,*) 'Looking for existence of ', TRIM(file_in_SSS)
     inquire(file=file_in_SSS, exist=existfile)
     if ( existfile ) then; write(*,*) 'BINGO !'; exit ; endif
  enddo !-kfmt

  IF ( existfile ) THEN

    write(*,*) 'Reading T,S input dimensions in ', TRIM(file_in_SSS)
    status = NF90_OPEN(TRIM(file_in_SSS),0,fidSSS)          ; call erreur(status,.TRUE.,"read first")

    status = NF90_INQ_DIMID(fidSSS,"time_counter",dimID_time) ; call erreur(status,.TRUE.,"inq_dimID_time")
    status = NF90_INQ_DIMID(fidSSS,"x",dimID_x)               ; call erreur(status,.TRUE.,"inq_dimID_x")
    status = NF90_INQ_DIMID(fidSSS,"y",dimID_y)               ; call erreur(status,.TRUE.,"inq_dimID_y")
    !- Figure out whether 2D or 3D salinity file :
    ln_2d = .false.
    status = NF90_INQ_DIMID(fidSSS,"z",dimID_z)
    if ( status .ne. 0 ) status = NF90_INQ_DIMID(fidSSS,"depth",dimID_z)
    if ( status .ne. 0 ) status = NF90_INQ_DIMID(fidSSS,"deptht",dimID_z)
    if ( status .ne. 0 ) status = NF90_INQ_DIMID(fidSSS,"nav_lev",dimID_z)
    if ( status .ne. 0 ) ln_2d = .true.

    status = NF90_INQUIRE_DIMENSION(fidSSS,dimID_time,len=mtime)     ; call erreur(status,.TRUE.,"inq_dim_time")
    status = NF90_INQUIRE_DIMENSION(fidSSS,dimID_x,len=mx_PAR)         ; call erreur(status,.TRUE.,"inq_dim_x")
    status = NF90_INQUIRE_DIMENSION(fidSSS,dimID_y,len=my_PAR)         ; call erreur(status,.TRUE.,"inq_dim_y")
    if ( .not. ln_2d ) then
      status = NF90_INQUIRE_DIMENSION(fidSSS,dimID_z,len=mz_PAR)
      call erreur(status,.TRUE.,"inq_dim_z")
      if ( mz_PAR .eq. 1 ) then
        ln_2d = .true.
      else
        write(*,*) 'Reading sea surface salinity from 3-dimensional files'
      endif
    endif

    write(*,*) 'dimensions :', mx_PAR, my_PAR

    ALLOCATE( nav_lon(mx_PAR,my_PAR), nav_lat(mx_PAR,my_PAR) )

    status = NF90_INQ_VARID(fidSSS,"nav_lon",lon_ID)
    if ( status .ne. 0 ) status = NF90_INQ_VARID(fidSSS,"lon",lon_ID)
    if ( status .ne. 0 ) status = NF90_INQ_VARID(fidSSS,"longitude",lon_ID)
    call erreur(status,.TRUE.,"inq_lon_ID")
    status = NF90_INQ_VARID(fidSSS,"nav_lat",lat_ID)
    if ( status .ne. 0 ) status = NF90_INQ_VARID(fidSSS,"lat",lat_ID)
    if ( status .ne. 0 ) status = NF90_INQ_VARID(fidSSS,"latitude",lat_ID)
    call erreur(status,.TRUE.,"inq_lat_ID")
        
    status = NF90_GET_VAR(fidSSS,lon_ID,nav_lon)                    ; call erreur(status,.TRUE.,"getvar_lon")
    status = NF90_GET_VAR(fidSSS,lat_ID,nav_lat)                    ; call erreur(status,.TRUE.,"getvar_lat")

    status = NF90_CLOSE(fidSSS)                                     ; call erreur(status,.TRUE.,"fin_lecture")

    exit

  ELSEIF ( kday .eq. 31 ) THEN

    write(*,*) 'No SSS file found for first month of ', kyear
    write(*,*) '        >>>>>>>>>>>>>>>>>> stop !!'
    stop

  ENDIF

ENDDO

!- Read tmask in parent grid file:
status = NF90_OPEN(TRIM(file_sss_mask),0,fidMSKIN);     call erreur(status,.TRUE.,"read mask_PAR") 
status = NF90_INQ_DIMID(fidMSKIN,"z",dimID_z)
if ( status .ne. 0 ) status = NF90_INQ_DIMID(fidMSKIN,"depth",dimID_z)
if ( status .ne. 0 ) status = NF90_INQ_DIMID(fidMSKIN,"deptht",dimID_z)
if ( status .ne. 0 ) status = NF90_INQ_DIMID(fidMSKIN,"nav_lev",dimID_z)
status = NF90_INQUIRE_DIMENSION(fidMSKIN,dimID_z,len=mz_PAR)
ALLOCATE(  tmask(mx_PAR,my_PAR,mz_PAR), tmask_PAR(mx_PAR,my_PAR)  ) 
status = NF90_INQ_VARID(fidMSKIN,"tmask",tmask_PAR_ID); call erreur(status,.TRUE.,"inq_tmask_PAR_ID")
status = NF90_GET_VAR(fidMSKIN,tmask_PAR_ID,tmask);     call erreur(status,.TRUE.,"getvar_tmask_PAR")
tmask_PAR(:,:)=tmask(:,:,1)
DEALLOCATE(tmask)
status = NF90_CLOSE(fidMSKIN);                          call erreur(status,.TRUE.,"end read mask_PAR")

!- create SSS directory :
write(command_str,888) TRIM(config_dir)
888 FORMAT('mkdir -pv ',a,'/SSS')
CALL system(TRIM(command_str))

!=================================================================================
! 4- Process all gridT files over specified period
!=================================================================================

DO kyear=nn_sss_yeari,nn_sss_yearf

  DO kmonth=1,12

    DO kday=1,31

      SELECT CASE(nfmt)
        CASE(191)
          write(file_in_SSS,191) TRIM(sss_dir), kyear, TRIM(sss_prefix), kyear, TRIM(sss_sep1), kmonth, TRIM(sss_sep2), kday, TRIM(sss_suffix)
        CASE(192)
          write(file_in_SSS,192) TRIM(sss_dir), kyear, TRIM(sss_prefix), kyear, TRIM(sss_sep1), kmonth, TRIM(sss_suffix) 
        CASE(193)
          write(file_in_SSS,193) TRIM(sss_dir), TRIM(sss_prefix), kyear, TRIM(sss_sep1), kmonth, TRIM(sss_sep2), kday, TRIM(sss_suffix)
        CASE(194)
          write(file_in_SSS,194) TRIM(sss_dir), TRIM(sss_prefix), kyear, TRIM(sss_sep1), kmonth, TRIM(sss_suffix)
        CASE(195)
          write(file_in_SSS,195) TRIM(sss_dir), TRIM(sss_prefix)
        CASE DEFAULT 
          write(*,*) 'wrong nfmt value >>>>>> stop !'
          stop
      END SELECT
      inquire(file=file_in_SSS, exist=existfile)

      IF ( existfile ) THEN

        ! output file format :
        if     ( nfmt .eq. 191 .or. nfmt .eq. 193 ) then
          401 FORMAT(a,'/SSS/sss_',i4.4,'_',i2.2,'_',i2.2,'_',a,'.nc')
          write(file_CHLD_SSS,401) TRIM(config_dir), kyear, kmonth, kday, TRIM(config)
        elseif ( nfmt .eq. 192 .or. nfmt .eq. 194 ) then
          402 FORMAT(a,'/SSS/sss_',i4.4,'_',i2.2,'_',a,'.nc')
          write(file_CHLD_SSS,402) TRIM(config_dir), kyear, kmonth, TRIM(config)
        elseif ( nfmt .eq. 195 ) then
          403 FORMAT(a,'/sss_climato_',a,'.nc')
          write(file_CHLD_SSS,403) TRIM(config_dir), TRIM(config)
        else
          write(*,*) 'Do not forget to include new file format in the format definition for file_CHLD_SSS  >>>> stop'
          stop
        endif

        ALLOCATE( vosaline_PAR(mx_PAR,my_PAR,mtime)  )
        if ( .not. ln_2d ) ALLOCATE( vosaline_3d(mx_PAR,my_PAR,mz_PAR,mtime)  )
        ALLOCATE( time(mtime) )
        
        !---------------------------------------
        ! Read input SSS :

        write(*,*) 'Reading SSS in ', TRIM(file_in_SSS)
        
        status = NF90_OPEN(TRIM(file_in_SSS),0,fidSSS)                ; call erreur(status,.TRUE.,"read EXT TS") 
        
        status = NF90_INQ_VARID(fidSSS,"time_counter",time_ID)          ; call erreur(status,.TRUE.,"inq_time_ID")
        status = NF90_INQ_VARID(fidSSS,"vosaline",vosaline_ID)          ; call erreur(status,.TRUE.,"inq_vosaline_ID")
        
        status = NF90_GET_VAR(fidSSS,time_ID,time)                      ; call erreur(status,.TRUE.,"getvar_time")
        if ( ln_2d ) then
          status = NF90_GET_VAR(fidSSS,vosaline_ID,vosaline_PAR)        ; call erreur(status,.TRUE.,"getvar_vosaline")
        else
          status = NF90_GET_VAR(fidSSS,vosaline_ID,vosaline_3d)         ; call erreur(status,.TRUE.,"getvar_vosaline")
          vosaline_PAR(:,:,:) = vosaline_3d(:,:,1,:)
          DEALLOCATE( vosaline_3d )
        endif

!        status = NF90_GET_ATT(fidSSS,time_ID,"calendar",calendar)       ; call erreur(status,.TRUE.,"getatt_origin")
!        status = NF90_GET_ATT(fidSSS,time_ID,"units",time_units)        ; call erreur(status,.TRUE.,"getatt_units")
        
        status = NF90_CLOSE(fidSSS)                                     ; call erreur(status,.TRUE.,"fin_lecture")     

        !---------------------------------------
        ! Remove possible NaNs :
 
        do i=1,mx_PAR
        do j=1,my_PAR
        do l=1,mtime
          if ( .not. vosaline_PAR(i,j,l) .lt. 100.0 .and. .not. vosaline_PAR(i,j,l) .gt. 0.1 ) then
            vosaline_PAR(i,j,l) = 0.d0
          endif
        enddo
        enddo
        enddo

        !-------------------------------------------------
        ! convert to conservative temperature if needed :
        if ( nn_sss_eosmatch .eq. 0 ) then
          write(*,*) 'Converting from EOS80 to TEOS10 ...'
          do i=1,mx_PAR
          do j=1,my_PAR
            do l=1,mtime
              if ( vosaline_PAR(i,j,l) .gt. 1.0d-1 .and. vosaline_PAR(i,j,l) .lt. 1.0d2 ) then
                vosaline_PAR(i,j,l) = gsw_sa_from_sp( DBLE(vosaline_PAR(i,j,l)), 1.d0, DBLE(nav_lon(i,j)), DBLE(nav_lat(i,j)) )
              else
                vosaline_PAR(i,j,l) = 0.d0
              endif
            enddo
          enddo
          enddo
        elseif ( nn_sss_eosmatch .ne. 1 ) then
          write(*,*) '~!@#$%^* Error: nn_sss_eosmatch should be 0 or 1 >>>>> stop !!'
          stop
        endif
        
        !----------------------------------------------------------------------
        ! Just extract where ocean points on both parent and child grids :
        write(*,*) 'start extraction...'
        ALLOCATE( missing(mx_CHLD,my_CHLD) )
        ALLOCATE( tmp_missing(mx_CHLD,my_CHLD) )
        ALLOCATE( vosaline_CHLD(mx_CHLD,my_CHLD,mtime) )
        ALLOCATE( tmp_vosaline_CHLD(mx_CHLD,my_CHLD,mtime) )
        missing(:,:)=0
        vosaline_CHLD(:,:,:)=0.d0
        do iCHLD=1,mx_CHLD
        do jCHLD=1,my_CHLD
          iPAR=NINT(FLOAT(iCHLD+imin_EXT-1-bi)/ai)
          jPAR=NINT(FLOAT(jCHLD+jmin_EXT-1-bj)/aj)
          if ( iPAR .ge. 1 .and. jPAR .ge. 1 ) then
            if ( tmask_PAR(iPAR,jPAR) .eq. 1 ) then
              do l=1,mtime
                vosaline_CHLD(iCHLD,jCHLD,l) = vosaline_PAR(iPAR,jPAR,l) * tmask_CHLD(iCHLD,jCHLD) 
              enddo
            elseif ( tmask_CHLD(iCHLD,jCHLD) .eq. 1 ) then ! unmasked CHLD but masked PAR
              missing(iCHLD,jCHLD) = 1
            endif
          else ! part of the child domain not covered by the parent domain
            if ( tmask_CHLD(iCHLD,jCHLD) .eq. 1 ) missing(iCHLD,jCHLD) = 1
          endif
        enddo
        enddo
     
        ! Look for closest neighbours where we have missing values while tmask_CHLD=1:
        ntest2= NINT(sum(sum(1.0-FLOAT(tmask_CHLD(:,:)),2),1))
        nntrp = MAX(mx_CHLD/ai,my_CHLD/aj)
        do kiter=1,nntrp
          ntest = NINT(sum(sum(FLOAT(missing),2),1))
          write(*,*) '  kiter = ', kiter
          write(*,*) '     nb of pts with missing value: ', ntest, ' for nb of land pts: ', ntest2
          if ( ntest .eq. 0 .or. ntest .eq. ntest2 ) exit
          tmp_vosaline_CHLD(:,:,:)=vosaline_CHLD(:,:,:)
          tmp_missing(:,:)=missing(:,:)
          do iCHLD=1,mx_CHLD
          do jCHLD=1,my_CHLD
            if ( missing(iCHLD,jCHLD) .eq. 1 ) then
              iout=.FALSE.
              do rs=1,MAX(ai,aj)*(1+(nntrp-1)/3),1  ! rs=1,2,3 (3 times) then rs=1,2,3,4,5,6 (3 times, etc)
                  iii=iCHLD               ; jjj=jCHLD               
                  if ( tmask_CHLD(iii,jjj) .eq. 1 .and. missing(iii,jjj) .eq. 0 ) then ; iout=.TRUE. ; exit ; endif
                  iii=MIN(iCHLD+rs,mx_CHLD); jjj=jCHLD               
                  if ( tmask_CHLD(iii,jjj) .eq. 1 .and. missing(iii,jjj) .eq. 0 ) then ; iout=.TRUE. ; exit ; endif
                  iii=MAX(iCHLD-rs,1)     ; jjj=jCHLD               
                  if ( tmask_CHLD(iii,jjj) .eq. 1 .and. missing(iii,jjj) .eq. 0 ) then ; iout=.TRUE. ; exit ; endif
                  iii=iCHLD               ; jjj=MIN(jCHLD+rs,my_CHLD)
                  if ( tmask_CHLD(iii,jjj) .eq. 1 .and. missing(iii,jjj) .eq. 0 ) then ; iout=.TRUE. ; exit ; endif
                  iii=iCHLD               ; jjj=MAX(jCHLD-rs,1)     
                  if ( tmask_CHLD(iii,jjj) .eq. 1 .and. missing(iii,jjj) .eq. 0 ) then ; iout=.TRUE. ; exit ; endif
                  iii=MIN(iCHLD+rs,mx_CHLD); jjj=MIN(jCHLD+rs,my_CHLD)
                  if ( tmask_CHLD(iii,jjj) .eq. 1 .and. missing(iii,jjj) .eq. 0 ) then ; iout=.TRUE. ; exit ; endif
                  iii=MIN(iCHLD+rs,mx_CHLD); jjj=MAX(jCHLD-rs,1)     
                  if ( tmask_CHLD(iii,jjj) .eq. 1 .and. missing(iii,jjj) .eq. 0 ) then ; iout=.TRUE. ; exit ; endif
                  iii=MAX(iCHLD-rs,1)     ; jjj=MIN(jCHLD+rs,my_CHLD)
                  if ( tmask_CHLD(iii,jjj) .eq. 1 .and. missing(iii,jjj) .eq. 0 ) then ; iout=.TRUE. ; exit ; endif
                  iii=MAX(iCHLD-rs,1)     ; jjj=MAX(jCHLD-rs,1)     
                  if ( tmask_CHLD(iii,jjj) .eq. 1 .and. missing(iii,jjj) .eq. 0 ) then
                    iout=.TRUE.
                    exit
                  endif
                enddo !- rs
              if (iout) then
                tmp_missing(iCHLD,jCHLD) = 0
                tmp_vosaline_CHLD(iCHLD,jCHLD,:) = vosaline_CHLD(iii,jjj,:)
                exit
              elseif ( kiter .eq. nntrp ) then
                write(*,953) iCHLD, jCHLD
                953 FORMAT(' >>> ERROR for point (',2I5,')')
                stop
              endif
            endif !-if ( missing(iCHLD,jCHLD) .eq. 1 )
          enddo !- jCHLD
          enddo !- iCHLD
          missing(:,:)=tmp_missing(:,:)
          vosaline_CHLD(:,:,:)=tmp_vosaline_CHLD(:,:,:)
        enddo !- kiter
      
        !- Smoothing (i.e. bi-linear interpolation) :
        dij=INT(MAX(ai,aj)*0.5)
        write(*,*) 'Smoothing over plus and minus :', dij, ' pts'
        tmp_vosaline_CHLD(:,:,:)=vosaline_CHLD(:,:,:)
        do iCHLD=1,mx_CHLD
        do jCHLD=1,my_CHLD
            im1=MAX(iCHLD-dij,1) ; ip1=MIN(iCHLD+dij,mx_CHLD) 
            jm1=MAX(jCHLD-dij,1) ; jp1=MIN(jCHLD+dij,my_CHLD)
            if ( tmask_CHLD(iCHLD,jCHLD) .eq. 1 ) then 
              do l=1,mtime
                tmp_vosaline_CHLD(iCHLD,jCHLD,l) =   SUM( SUM( vosaline_CHLD(im1:ip1,jm1:jp1,l) * tmask_CHLD(im1:ip1,jm1:jp1), 2), 1) &
                &                               / SUM( SUM(                            1.0  * tmask_CHLD(im1:ip1,jm1:jp1), 2), 1)
              enddo
            else
              tmp_vosaline_CHLD(iCHLD,jCHLD,:) = 0.d0
            endif
        enddo
        enddo
        vosaline_CHLD(:,:,:)=tmp_vosaline_CHLD(:,:,:)
      
        !- "Drowning", i.e. put closest value everywhere on the mask file to avoid issue if namdom is slightly changed :
        !  We just repeat the previous methodology, but for masked points
        write(*,*) 'Drowning, i.e. fill all masked points with closest neighbour'
        missing(:,:)=NINT(1-FLOAT(tmask_CHLD(:,:)))
        ! Look for closest neighbours where we have missing values:
        do kiter=1,2*MAX(mx_CHLD/ai,my_CHLD/aj)
          ntest = NINT(sum(sum(FLOAT(missing),2),1))
          write(*,*) '  kiter = ', kiter
          write(*,*) '     remaining nb of masked points to fill: ', ntest
          if ( ntest .eq. 0 ) exit
          tmp_vosaline_CHLD(:,:,:)=vosaline_CHLD(:,:,:)
          tmp_missing(:,:)=missing(:,:)
          do iCHLD=1,mx_CHLD
          do jCHLD=1,my_CHLD
            if ( missing(iCHLD,jCHLD) .eq. 1 ) then
              iout=.FALSE.
              do rs=1,MAX(ai,aj),1
                  iii=iCHLD               ; jjj=jCHLD               
                  if ( missing(iii,jjj) .eq. 0 ) then ; iout=.TRUE. ; exit ; endif
                  iii=MIN(iCHLD+rs,mx_CHLD); jjj=jCHLD               
                  if ( missing(iii,jjj) .eq. 0 ) then ; iout=.TRUE. ; exit ; endif
                  iii=MAX(iCHLD-rs,1)     ; jjj=jCHLD               
                  if ( missing(iii,jjj) .eq. 0 ) then ; iout=.TRUE. ; exit ; endif
                  iii=iCHLD               ; jjj=MIN(jCHLD+rs,my_CHLD)
                  if ( missing(iii,jjj) .eq. 0 ) then ; iout=.TRUE. ; exit ; endif
                  iii=iCHLD               ; jjj=MAX(jCHLD-rs,1)     
                  if ( missing(iii,jjj) .eq. 0 ) then ; iout=.TRUE. ; exit ; endif
                  iii=MIN(iCHLD+rs,mx_CHLD); jjj=MIN(jCHLD+rs,my_CHLD)
                  if ( missing(iii,jjj) .eq. 0 ) then ; iout=.TRUE. ; exit ; endif
                  iii=MIN(iCHLD+rs,mx_CHLD); jjj=MAX(jCHLD-rs,1)     
                  if ( missing(iii,jjj) .eq. 0 ) then ; iout=.TRUE. ; exit ; endif
                  iii=MAX(iCHLD-rs,1)     ; jjj=MIN(jCHLD+rs,my_CHLD)
                  if ( missing(iii,jjj) .eq. 0 ) then ; iout=.TRUE. ; exit ; endif
                  iii=MAX(iCHLD-rs,1)     ; jjj=MAX(jCHLD-rs,1)     
                  if ( missing(iii,jjj) .eq. 0 ) then ; iout=.TRUE. ; exit ; endif
              enddo !- rs
              if (iout) then
                tmp_missing(iCHLD,jCHLD) = 0
                tmp_vosaline_CHLD(iCHLD,jCHLD,:) = vosaline_CHLD(iii,jjj,:)
                exit
              elseif ( kiter .eq. 2*MAX(mx_CHLD/ai,my_CHLD/aj) ) then
                tmp_missing(iCHLD,jCHLD) = 0
                tmp_vosaline_CHLD(iCHLD,jCHLD,:) = 0.d0
                exit
              endif
            endif !-if ( missing(iCHLD,jCHLD) .eq. 1 )
          enddo !- jCHLD
          enddo !- iCHLD
          missing(:,:)=tmp_missing(:,:)
          vosaline_CHLD(:,:,:)=tmp_vosaline_CHLD(:,:,:)
        enddo !- kiter
      
        !--  
        DEALLOCATE( tmp_vosaline_CHLD, tmp_missing, missing )

        !--------------------------------------
        ! Write SSS netcdf file

        write(*,*) 'Creating ', TRIM(file_CHLD_SSS)
        status = NF90_CREATE(TRIM(file_CHLD_SSS),NF90_NOCLOBBER,fidM) ; call erreur(status,.TRUE.,'create SSS file')                     

        status = NF90_DEF_DIM(fidM,"time_counter",NF90_UNLIMITED,dimID_time) ; call erreur(status,.TRUE.,"def_dimID_time_counter")
        status = NF90_DEF_DIM(fidM,"x",mx_CHLD,dimID_x)                       ; call erreur(status,.TRUE.,"def_dimID_x")
        status = NF90_DEF_DIM(fidM,"y",my_CHLD,dimID_y)                       ; call erreur(status,.TRUE.,"def_dimID_y")
        
        status = NF90_DEF_VAR(fidM,"time_counter",NF90_DOUBLE,(/dimID_time/),time_ID)
        call erreur(status,.TRUE.,"def_var_time_counter_ID")
        status = NF90_DEF_VAR(fidM,"vosaline",NF90_FLOAT,(/dimID_x,dimID_y,dimID_time/),vosaline_ID)
        call erreur(status,.TRUE.,"def_var_vosaline_ID")
        
        status = NF90_PUT_ATT(fidM,vosaline_ID,"associate","time_counter, z, y, x") ; call erreur(status,.TRUE.,"put_att_vosaline_ID")
        status = NF90_PUT_ATT(fidM,vosaline_ID,"missing_value",0.)                  ; call erreur(status,.TRUE.,"put_att_vosaline_ID")
        status = NF90_PUT_ATT(fidM,vosaline_ID,"_FillValue",0.)                     ; call erreur(status,.TRUE.,"put_att_vosaline_ID")
        status = NF90_PUT_ATT(fidM,vosaline_ID,"units","psu")                       ; call erreur(status,.TRUE.,"put_att_vosaline_ID")
        status = NF90_PUT_ATT(fidM,vosaline_ID,"long_name","practical salinity")    ; call erreur(status,.TRUE.,"put_att_vosaline_ID")
        status = NF90_PUT_ATT(fidM,vosaline_ID,"units","g/kg")                      ; call erreur(status,.TRUE.,"put_att_vosaline_ID")
        status = NF90_PUT_ATT(fidM,vosaline_ID,"long_name","absolute salinity")     ; call erreur(status,.TRUE.,"put_att_vosaline_ID")
!        status = NF90_PUT_ATT(fidM,time_ID,"units",TRIM(time_units))                ; call erreur(status,.TRUE.,"put_att_time_ID")
!        status = NF90_PUT_ATT(fidM,time_ID,"calendar",TRIM(calendar))               ; call erreur(status,.TRUE.,"put_att_time_ID")
        status = NF90_PUT_ATT(fidM,time_ID,"title","Time")                          ; call erreur(status,.TRUE.,"put_att_time_ID")
        status = NF90_PUT_ATT(fidM,time_ID,"long_name","Time axis")                 ; call erreur(status,.TRUE.,"put_att_time_ID")
        status = NF90_PUT_ATT(fidM,time_ID,"standard_name","time")                  ; call erreur(status,.TRUE.,"put_att_time_ID")
        status = NF90_PUT_ATT(fidM,time_ID,"axis","T")                              ; call erreur(status,.TRUE.,"put_att_time_ID")
        
        status = NF90_PUT_ATT(fidM,NF90_GLOBAL,"history","Created using extract_SSS_restoring.f90")
        status = NF90_PUT_ATT(fidM,NF90_GLOBAL,"tools","https://github.com/nicojourdain/BUILD_CONFIG_NEMO")
        call erreur(status,.TRUE.,"put_att_GLOBAL")
        
        status = NF90_ENDDEF(fidM) ; call erreur(status,.TRUE.,"fin_definition") 
        
        status = NF90_PUT_VAR(fidM,time_ID,time)             ; call erreur(status,.TRUE.,"var_time_ID")
        status = NF90_PUT_VAR(fidM,vosaline_ID,vosaline_CHLD) ; call erreur(status,.TRUE.,"var_vosaline_ID")
        
        status = NF90_CLOSE(fidM) ; call erreur(status,.TRUE.,"close new SSS file")

        !--       
        DEALLOCATE( vosaline_PAR, time )
        DEALLOCATE( vosaline_CHLD )

        !--
        if     ( nfmt .eq. 191 .or. nfmt .eq. 193 ) then
          write(*,*) 'Looking for next existing day in this month/year'
        elseif ( nfmt .eq. 192 .or. nfmt .eq. 194 .or. nfmt .eq. 195 ) then
          write(*,*) 'Only one file per month => switching to next month'
          exit
        else
          write(*,*) 'Keep in mind to decide how to end the main loop according to new file format  >>>> stop'
          stop
        endif

      ENDIF

    ENDDO !-kday
  ENDDO !- kmonth
ENDDO !- kyear

end program modif

!=============================================

SUBROUTINE erreur(iret, lstop, chaine)
  ! pour les messages d'erreur
  USE netcdf
  INTEGER, INTENT(in)                     :: iret
  LOGICAL, INTENT(in)                     :: lstop
  CHARACTER(LEN=*), INTENT(in)            :: chaine
  !
  CHARACTER(LEN=80)                       :: message
  !
  IF ( iret .NE. 0 ) THEN
    WRITE(*,*) 'ROUTINE: ', TRIM(chaine)
    WRITE(*,*) 'ERREUR: ', iret
    message=NF90_STRERROR(iret)
    WRITE(*,*) 'CA VEUT DIRE:',TRIM(message)
    IF ( lstop ) STOP
  ENDIF
  !
END SUBROUTINE erreur
