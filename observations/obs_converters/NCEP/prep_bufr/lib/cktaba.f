      SUBROUTINE CKTABA(LUN,SUBSET,JDATE,IRET)

C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM:    CKTABA
C   PRGMMR: WOOLLEN          ORG: NP20       DATE: 2000-09-19
C
C ABSTRACT: THIS SUBROUTINE PARSES THE TABLE A MNEMONIC AND THE DATE
C   OUT OF SECTION 1 OF A BUFR MESSAGE PREVIOUSLY READ FROM UNIT LUNIT
C   USING BUFR ARCHIVE LIBRARY SUBROUTINE READMG OR EQUIVALENT (AND NOW
C   STORED IN THE INTERNAL MESSAGE BUFFER, ARRAY MBAY IN COMMON BLOCK
C   /BITBUF/).  THE TABLE A MNEMONIC IS ASSOCIATED WITH THE BUFR
C   MESSAGE TYPE/SUBTYPE IN SECTION 1.  IT ALSO FILLS IN THE MESSAGE
C   CONTROL WORD PARTITION ARRAYS IN COMMON BLOCK /MSGCWD/.
C
C PROGRAM HISTORY LOG:
C 2000-09-19  J. WOOLLEN -- ORIGINAL AUTHOR - CONSOLIDATED MESSAGE
C                           DECODING LOGIC THAT HAD BEEN REPLICATED IN
C                           READMG, READFT, READERME, RDMEMM AND READIBM
C                           (CKTABA IS NOW CALLED BY THESE CODES);
C                           LOGIC ENHANCED HERE TO ALLOW COMPRESSED AND
C                           STANDARD BUFR MESSAGES TO BE READ
C 2003-11-04  S. BENDER  -- ADDED REMARKS/BUFRLIB ROUTINE
C                           INTERDEPENDENCIES
C 2003-11-04  D. KEYSER  -- MODIFIED TO NOT ABORT WHEN THE SECTION 1
C                           MESSAGE SUBTYPE DOES NOT AGREE WITH THE
C                           SECTION 1 MESSAGE SUBTYPE IN THE DICTIONARY
C                           IF THE MESSAGE TYPE MNEMONIC IS NOT OF THE
C                           FORM "NCtttsss", WHERE ttt IS THE BUFR TYPE
C                           AND sss IS THE BUFR SUBTYPE (E.G., IN
C                           "PREPBUFR" FILES); MODIFIED DATE
C                           CALCULATIONS TO NO LONGER USE FLOATING
C                           POINT ARITHMETIC SINCE THIS CAN LEAD TO
C                           ROUND OFF ERROR AND AN IMPROPER RESULTING
C                           DATE ON SOME MACHINES (E.G., NCEP IBM
C                           FROST/SNOW), INCREASES PORTABILITY;
C                           UNIFIED/PORTABLE FOR WRF; ADDED
C                           DOCUMENTATION (INCLUDING HISTORY); OUTPUTS
C                           MORE COMPLETE DIAGNOSTIC INFO WHEN ROUTINE
C                           TERMINATES ABNORMALLY OR UNUSUAL THINGS
C                           HAPPEN; SUBSET DEFINED AS "        " IF
C                           IRET RETURNED AS 11 (BEFORE WAS UNDEFINED)
C 2004-08-09  J. ATOR    -- MAXIMUM MESSAGE LENGTH INCREASED FROM
C                           20,000 TO 50,000 BYTES
C 2005-11-29  J. ATOR    -- USE IUPBS01, IGETDATE AND GETLENS
C 2006-04-14  J. ATOR    -- ALLOW "FRtttsss" AND "FNtttsss" AS POSSIBLE
C                           TABLE A MNEMONICS, WHERE ttt IS THE BUFR
C                           TYPE AND sss IS THE BUFR SUBTYPE
C DART $Id$
C
C USAGE:    CALL CKTABA (LUN, SUBSET, JDATE, IRET)
C   INPUT ARGUMENT LIST:
C     LUN      - INTEGER: I/O STREAM INDEX INTO INTERNAL MEMORY ARRAYS
C
C   OUTPUT ARGUMENT LIST:
C     SUBSET   - CHARACTER*8: TABLE A MNEMONIC FOR TYPE OF BUFR MESSAGE
C                BEING CHECKED
C              "        " = IRET equal to 11 (see IRET below)
C     JDATE    - INTEGER: DATE-TIME STORED WITHIN SECTION 1 OF BUFR
C                MESSAGE BEING CHECKED, IN FORMAT OF EITHER YYMMDDHH OR
C                YYYYMMDDHH, DEPENDING ON DATELEN() VALUE 
C     IRET     - INTEGER: RETURN CODE:
C                       0 = normal return
C                      -1 = unrecognized Table A (message type) value
C                      11 = this is a BUFR table (dictionary) message
C
C   OUTPUT FILES:
C     UNIT 06  - STANDARD OUTPUT PRINT
C
C REMARKS:
C    THIS ROUTINE CALLS:        BORT     DIGIT    GETLENS  I4DY
C                               IGETDATE IUPB     IUPBS01  NEMTBAX
C                               NUMTAB   OPENBT   RDUSDX
C    THIS ROUTINE IS CALLED BY: RDMEMM   READERME READMG   READMM
C                               Normally not called by any application
C                               programs.
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 77
C   MACHINE:  PORTABLE TO ALL PLATFORMS
C
C$$$

      INCLUDE 'bufrlib.prm'

      COMMON /MSGCWD/ NMSG(NFILES),NSUB(NFILES),MSUB(NFILES),
     .                INODE(NFILES),IDATE(NFILES)
      COMMON /BITBUF/ MAXBYT,IBIT,IBAY(MXMSGLD4),MBYT(NFILES),
     .                MBAY(MXMSGLD4,NFILES)
      COMMON /PADESC/ IBCT,IPD1,IPD2,IPD3,IPD4
      COMMON /UNPTYP/ MSGUNP(NFILES)
      COMMON /QUIET / IPRT

      CHARACTER*128 BORT_STR
      CHARACTER*8   SUBSET
      CHARACTER*2   CPFX(3)
      CHARACTER*1   TAB
      LOGICAL       TRYBT, DIGIT

      DATA CPFX   / 'NC', 'FR', 'FN' /
      DATA NCPFX  / 3 /

C-----------------------------------------------------------------------
C-----------------------------------------------------------------------

      TRYBT = .TRUE.

      JDATE = IGETDATE(MBAY(1,LUN),IYR,IMO,IDY,IHR)

c  .... Message type
      MTYP = IUPBS01(MBAY(1,LUN),'MTYP')
c  .... Message subtype
      MSBT = IUPBS01(MBAY(1,LUN),'MSBT')

C  DON'T PARSE BUFR TABLE (DICTIONARY) MESSAGES
C  --------------------------------------------

      IF(MTYP.EQ.11) THEN
         IF(IPRT.GE.2)  THEN
      PRINT*
      PRINT*,'+++++++++++++++++BUFR ARCHIVE LIBRARY++++++++++++++++++++'
            PRINT*,'BUFRLIB: CKTABA - TABLE A VALUE IS 11 (THIS IS A ',
     .       'BUFR TABLE DICTIONARY MESSAGE) - RETURN WITH IRET = 11'
      PRINT*,'+++++++++++++++++BUFR ARCHIVE LIBRARY++++++++++++++++++++'
      PRINT*
         ENDIF

C  Return with IRET=1 and SUBSET all blanks
C  ----------------------------------------

         IRET = 11
         SUBSET = "        "
         GOTO 100
      ENDIF

C  PARSE SECTION 3
C  ---------------

      CALL GETLENS(MBAY(1,LUN),3,LEN0,LEN1,LEN2,LEN3,L4,L5)

      IAD3 = LEN0+LEN1+LEN2

c  .... Number of subsets in msg
      JSUB = IUPB(MBAY(1,LUN),IAD3+5 ,16)
c  .... Compression indicator
      NCMP = IUPB(MBAY(1,LUN),IAD3+7 ,8 )
c  .... First descriptor (integer)
      KSUB = IUPB(MBAY(1,LUN),IAD3+8 ,16)
c  .... Second descriptor (integer)
      ISUB = IUPB(MBAY(1,LUN),IAD3+10,16)

C  LOCATE SECTION 4
C  ----------------

      IAD4 = IAD3+LEN3

C  NOW, TRY TO GET "SUBSET" (MNEMONIC ASSOCIATED WITH TABLE A) FROM MSG
C  --------------------------------------------------------------------

C  IF ISUB FROM SECTION 3 DEFINES TABLE A THEN MSGUNP=0
C  ----------------------------------------------------

c  .... get SUBSET from ISUB
5     CALL NUMTAB(LUN,ISUB,SUBSET,TAB,ITAB)
c  .... is SUBSET from Tbl A?
      CALL NEMTBAX(LUN,SUBSET,MTY1,MSB1,INOD)
      IF(INOD.GT.0) THEN
c  .... yes it is
         MBYT(LUN) = (IAD4+4)
         MSGUNP(LUN) = 0
         GOTO 10
      ENDIF

C  IF KSUB FROM SECTION 3 DEFINES TABLE A THEN MSGUNP=1 (standard)
C  ---------------------------------------------------------------

c  .... get SUBSET from KSUB
      CALL NUMTAB(LUN,KSUB,SUBSET,TAB,ITAB)
c  .... is SUBSET from Tbl A?
      CALL NEMTBAX(LUN,SUBSET,MTY1,MSB1,INOD)
      IF(INOD.GT.0) THEN
c  .... yes it is
         MBYT(LUN) = 8*(IAD4+4)
         MSGUNP(LUN) = 1
         GOTO 10
      ENDIF

C  OKAY, STILL NO "SUBSET", LETS MAKE IT "NCtttsss" (where ttt=MTYP
C  and sss=MSBT) AND SEE IF IT DEFINES TABLE A.  IF NOT, THEN ALSO
C  TRY "FRtttsss" AND "FNtttsss".
C  ----------------------------------------------------------------

      II=1
      DO WHILE(II.LE.NCPFX)
         WRITE(SUBSET,'(A2,2I3.3)') CPFX(II),MTYP,MSBT
c  ....    is SUBSET from Tbl A?
         CALL NEMTBAX(LUN,SUBSET,MTY1,MSB1,INOD)
         IF(INOD.GT.0) THEN
c  ....     yes it is
            IF(KSUB.EQ.IBCT) THEN
               MBYT(LUN) = (IAD4+4)
               MSGUNP(LUN) = 0
            ELSE
               MBYT(LUN) = 8*(IAD4+4)
               MSGUNP(LUN) = 1
            ENDIF
            GOTO 10
         ENDIF
         II=II+1
      ENDDO

C  NOW WE HAVE A GENERATED "SUBSET", BUT IT STILL DOES NOT DEFINE
C  TABLE A - MAKE ONE LAST DESPERATE ATTEMPT - SEE IF AN EXTERNAL
C  USER-SUPPLIED BUFR DICTIONARY TABLE IN CHARACTER FORMAT IS DEFINED
C  IN OPENBT (ONLY POSSIBLE IF APPLICATION PROGRAM HAS AN IN-LINE
C  OPENBT OVERRIDING THE ONE IN THE BUFR ARCHIVE LIBRARY)
C  ------------------------------------------------------------------

      IF(TRYBT) THEN
         TRYBT = .FALSE.
         IF(IPRT.GE.1) THEN
      PRINT*
      PRINT*,'+++++++++++++++++BUFR ARCHIVE LIBRARY++++++++++++++++++++'
            PRINT*, 'BUFRLIB: CKTABA - LAST RESORT, CHECK FOR EXTERNAL',
     .       ' BUFR TABLE VIA CALL TO IN-LINE OPENBT'
      PRINT*,'+++++++++++++++++BUFR ARCHIVE LIBRARY++++++++++++++++++++'
      PRINT*
         ENDIF
         CALL OPENBT(LUNDX,MTYP)
         IF(LUNDX.GT.0) THEN
c  .... Good news, there is a unit (LUNDX) connected to a table file,
c  .... so store the table internally
            CALL RDUSDX(LUNDX,LUN)
            GOTO 5
         ENDIF
      ENDIF

C  IF ALL ATTEMPTS TO DEFINE TABLE A FAIL SKIP GIVE UP
C  ---------------------------------------------------

      IF(IPRT.GE.0)  THEN
      PRINT*
      PRINT*,'+++++++++++++++++++++++WARNING+++++++++++++++++++++++++'
      PRINT*,'BUFRLIB: CKTABA - UNRECOGNIZED TABLE A MESSAGE TYPE (',
     . SUBSET, ') - RETURN WITH IRET = -1'
      PRINT*,'+++++++++++++++++++++++WARNING+++++++++++++++++++++++++'
      PRINT*
      ENDIF
      IRET = -1
      GOTO 100

C  CHECK THE VALIDITY OF THE MTYP/MSBT AND FOR COMPRESSION (MSGUNP=2)
C  ------------------------------------------------------------------

10    CONTINUE
      IF(MTYP.NE.MTY1) GOTO 900
      IF(MSBT.NE.MSB1.AND.DIGIT(SUBSET(3:8))) GOTO 901
      IF(IAND(NCMP,64).GT.0) MSGUNP(LUN) = 2

C  SET THE OTHER REQUIRED PARAMETERS IN MESSAGE CONTROL WORD PARTITION
C  -------------------------------------------------------------------

c  .... Date for this message
      IDATE(LUN) = I4DY(JDATE)
c  .... Number of messages so far in file
      NMSG (LUN) = NMSG(LUN)+1
c  .... Positional index of Table A mnem.
      INODE(LUN) = INOD
c  .... Number of subsets in this message
      MSUB (LUN) = JSUB
c  .... Number of subsets actually read so far
      NSUB (LUN) = 0

c  .... Return successfully
      IRET = 0

C  EXITS
C  -----

100   RETURN
900   WRITE(BORT_STR,'("BUFRLIB: CKTABA - MESSAGE TYPE MISMATCH '//
     . '(SUBSET=",A8,", MTYP=",I3,", MTY1=",I3)') SUBSET,MTYP,MTY1
      CALL BORT(BORT_STR)
901   WRITE(BORT_STR,'("BUFRLIB: CKTABA - MESSAGE SUBTYPE MISMATCH '//
     . '(SUBSET=",A8,", MSBT=",I3,", MSB1=",I3)') SUBSET,MSBT,MSB1
      CALL BORT(BORT_STR)
      END
