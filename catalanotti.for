C----------------------------------------------------------------------C
C     ABAQUS VUMAT USER SUBROUTINE: catalanotti_FC.for                 C
C	  Author(s): Rutger Kok, Francisca Martinez-Hergueta               C
C     Date: 28/06/2019                                           	   C
C     Version 1.0                                                      C
C----------------------------------------------------------------------C

C User subroutine VUMAT
      SUBROUTINE vumat (
C Read only -
     *     nblock, ndir, nshr, nstatev, nfieldv, nprops, lanneal,
     *     stepTime, totalTime, dt, cmname, coordMp, charLength,
     *     props, density, strainInc, relSpinInc,
     *     tempOld, stretchOld, defgradOld, fieldOld,
     *     stressOld, stateOld, enerInternOld, enerInelasOld,
     *     tempNew, stretchNew, defgradNew, fieldNew,
C Write only -
     *     stressNew, stateNew, enerInternNew, enerInelasNew )

      INCLUDE 'vaba_param.inc'

      dimension coordMp(nblock,*), charLength(nblock), props(nprops),
     1     density(nblock), strainInc(nblock,ndir+nshr),
     2     relSpinInc(nblock,nshr), tempOld(nblock),
     3     stretchOld(nblock,ndir+nshr), 
     4     defgradOld(nblock,ndir+nshr+nshr),
     5     fieldOld(nblock,nfieldv), stressOld(nblock,ndir+nshr),
     6     stateOld(nblock,nstatev), enerInternOld(nblock),
     7     enerInelasOld(nblock), tempNew(nblock),
     8     stretchNew(nblock,ndir+nshr),
     9     defgradNew(nblock,ndir+nshr+nshr),
     1     fieldNew(nblock,nfieldv),
     2     stressNew(nblock,ndir+nshr), stateNew(nblock,nstatev),
     3     enerInternNew(nblock), enerInelasNew(nblock)
     
      REAL*8 trialStress(6),trialStrain(6)
      REAL*8 xomega(6)
      REAL*8 d1Plus,d1Minus,d2Plus,d2Minus,d6
      REAL*8 rNew1,rNew2,rNew3,rNew4,rNew5,rNew6
      REAL*8 e11,e22,e33,xnu12,xnu13,xnu23,xmu12,xmu13,xmu23
      REAL*8 XT,XC,YT,YC,SL
      REAL*8 G1plus,G1minus,G2plus,G2minus,G6
      REAL*8 A1plus,A1minus,A2plus,A2minus,A6
      REAL*8 alpha0,etaT,etaL,phiC,ST,omegaValue
      REAL*8 FI_LT,FI_LC,FI_MT,FI_MC
      REAL*8 initialcharLength,thickness,traceStrain,meanDamage,expo, A
      REAL*8 trialStressP(6), X, NEWT, FUNC, DFUNC
      CHARACTER*80 cmname
      PARAMETER ( zero = 0.d0, one = 1.d0, two = 2.d0, three = 3.0d0,
     *     third = 1.d0 / 3.d0, half = 0.5d0, six = 6.0d0)

C Elastic constants orthotropic ply

      e11   = props(1)
      e22   = props(2)
      e33   = props(3)
      xnu12 = props(4)
      xnu13 = props(5)
      xnu23 = props(6)
      xmu12 = props(7)
      xmu13 = props(8)
      xmu23 = props(9)

C Ply strength

      XT = props(10)
      XC = props(11)
      YT = props(12)
      YC = props(13)
      SL = props(14)

C Fracture Angle

      alpha0 = props(15)*0.017453292519943295

C Fracture toughness

      G1plus = props(16)
      G1minus = props(17)
      G2plus = props(18)
      G2minus = props(19)
      G6 = props(20)

C Initial values

      etaL = 0.5
      phiC = atan((1.0d0-sqrt(1.0d0-4.0d0*(SL/XC)*((SL/XC)+etaL))) !Eq.12
     1       /(2.0d0*((SL/XC)+etaL)))
      ST = (0.5*(((2*sin(alpha0)**2.0)-1.0)*Sl_is)/  !Eq.12 (CLN)
     1     (((1-sin(alpha0)**2.0)**0.5)*sin(alpha0)*etaL))
      etaT = (etaL*ST)/SL                      !Eq.10 CLN
      kappa = (ST**2.0d0-YT**2.0)/(ST*YT)  !Eq.43 CLN
      lambda = ((2.0*etaL*ST)/SL)-kappa  !Eq.45 CLN 
      omegaValue = -0.120382            !Eq.20

C Stiffness matrix orthotropic material

      xnu21 = xnu12*e22/e11
      xnu31 = xnu13*e33/e11
      xnu32 = xnu23*e33/e22

      xnu = 1.0/(1.0-xnu12*xnu21-xnu32*xnu23-xnu13*xnu31
     1      -2.0*xnu21*xnu13*xnu32)

      d11 = e11*(1.0-xnu23*xnu32)*xnu
      d22 = e22*(1.0-xnu13*xnu31)*xnu 
      d33 = e33*(1.0-xnu12*xnu21)*xnu
      d12 = e11*(xnu21+xnu31*xnu23)*xnu
      d13 = e11*(xnu31+xnu21*xnu32)*xnu
      d23 = e22*(xnu32+xnu12*xnu31)*xnu
      d44 = 2.0*xmu12
      d55 = 2.0*xmu23
      d66 = 2.0*xmu13   

C Loop through the gauss points

      IF (stepTime.eq.0) THEN     

      ! Initial elastic step, for Abaqus tests
      DO k = 1, nblock
      
       ! Initialisation of state variables
       DO k1 = 1,nstatev
            stateNew(k,k1) = 0.d0
       ENDDO

       DO i = 1,6
           trialStrain(i)=strainInc(k,i)
       ENDDO

       trialStress(1) = d11*trialStrain(1)+d12*trialStrain(2)
     1                  +d13*trialStrain(3)
       trialStress(2) = d12*trialStrain(1)+d22*trialStrain(2)
     1                  +d23*trialStrain(3)
       trialStress(3) = d13*trialStrain(1)+d23*trialStrain(2)
     1                  +d33*trialStrain(3)
       trialStress(4) = d44*trialStrain(4)
       trialStress(5) = d55*trialStrain(5)
       trialStress(6) = d66*trialStrain(6)

       DO i = 1,6
           stressNew(k,i)=trialStress(i)
       ENDDO

      ENDDO

      ELSE

       ! Constitutive model definition

       ! Update of the failure thresholds (r values)
       DO k = 1,nblock
        rOld1 = stateOld(k,7)
        rOld2 = stateOld(k,8)
        rOld3 = stateOld(k,9)
        rOld4 = stateOld(k,10)
        rOld5 = stateOld(k,11)
        rOld6 = stateOld(k,12)

        ! Computation of the total strain
        DO i = 1,6
            stateNew(k,i)=stateOld(k,i)+strainInc(k,i)
        ENDDO

        DO i = 1,6
            trialStrain(i)=stateNew(k,i)
        ENDDO

        !Trial stress
        trialStress(1) = d11*trialStrain(1)+d12*trialStrain(2)
     1                   +d13*trialStrain(3)
        trialStress(2) = d12*trialStrain(1)+d22*trialStrain(2)
     1                   +d23*trialStrain(3)
        trialStress(3) = d13*trialStrain(1)+d23*trialStrain(2)
     1                   +d33*trialStrain(3)
        trialStress(4) = d44*trialStrain(4)
        trialStress(5) = d55*trialStrain(5)
        trialStress(6) = d66*trialStrain(6)

        DO i = 1,6
            stressNew(k,i)=trialStress(i)
        ENDDO

        ! Evaluation of the damage activation functions

        ! longitudinal failure criteria
        IF (trialStress(1).gt.0.d0) THEN
            FI_LT = trialStrain(1)/(XT/e11) ! Eq. 54 CLN
        ELSEIF (trialStress(1).lt.0.d0) THEN
            call ROTATE_PHI(trialStress,phiC,XC,trialStressP)
            call FAIL_CLN(trialStress,ST,YT,SL,etaL,etaT,lambda,kappa,
     1                    FI_LT,FI_LC)
        ENDIF
    
        ! transverse failure criteria
        call FAIL_CLN(trialStress,ST,YT,SL,etaL,etaT,lambda,kappa,
     1                    FI_MT,FI_MC)

        ! Update of the damage thresholds
        rNew1 = max(1.0,max(FI_LT,rOld1),max(FI_LC,rOld2))    !Eq.26
        rNew2 = max(1.0,max(FI_LC,rOld2))
        rNew3 = max(1.0,max(FI_MT,rOld3),max(FI_MC,rOld4))
        rNew4 = max(1.0,max(FI_MC,rOld4))
        rNew5 = 1.0d0
        rNew6 = 1.0d0

        ! Softening parameters
        initialcharLength = 1.0
        
        A1plus = 2.0d0*initialcharLength*XT*XT  !Second part. eq. B.2       
     1           /(2.0d0*e11*G1plus-initialcharLength*XT*XT)
        
        A1minus = 2.0d0*initialcharLength  ! Second part. Appendix B
     1            *(1.2671444971783234*XC)**2.0d0 
     2            /(2.0d0*(1.173191594009027*e11)
     3            *G1minus-initialcharLength
     4            *(1.145996547107106*XC)**2.0d0)
      
        A2plus = 2.0d0*initialcharLength*(0.8308920721648098*YT)**2.0d0
     1           /(2.0d0*0.9159840495203727*e22*G2plus
     2           -initialcharLength*(0.9266465446084761*YT)**2.0d0)

        A2minus = 2.0d0*initialcharLength*(0.709543*YC)**2.0d0
     1            /(2.0d0*0.7881*e22*G2minus-initialcharLength
     2            *(0.802572*YC)**2.0d0)

        A6 = 2.0d0*initialcharLength*SL*SL
     1       /(2.0d0*xmu12*G6-initialcharLength*SL*SL)
     
        A6 = A2plus
 
        d1Plus = 1.0d0-1.0d0/rNew1*dexp(A1plus*(1.0d0-rNew1))     !Eq.28
        d1Minus = 1.0d0-1.0d0/rNew2*dexp(A1minus*(1.0d0-rNew2))
        d2Plus = 1.0d0-1.0d0/rNew3*dexp(A2plus*(1.0d0-rNew3))
        d2Minus = 1.0d0-1.0d0/rNew4*dexp(A2minus*(1.0d0-rNew4))
        d6 = 1.0d0-1.0d0/rNew3*dexp(A6*(1.0d0-rNew3))*(1.0d0-d1Plus)

        ! Damage variables

        IF (trialStress(1).gt.0) THEN      !Eq.6
            xOmega1 = d1Plus
        ELSE
            xOmega1 = d1Minus
        ENDIF

        IF (trialStress(2).gt.0) THEN
            xOmega2 = d2Plus
        ELSE
            xOmega2 = d2Minus
        ENDIF

        xOmega4 = d6
        xOmega3 = 0.0d0
        xOmega5 = 0.0d0
        xOmega6 = 0.0d0 

        ! Stiffness tensor + damage

        xnu21 = xnu12*e22/e11
        xnu31 = xnu13*e33/e11
        xnu32 = xnu23*e33/e22
 
        xnu = 1.0d0/(1.0d0-xnu12*xnu21*(1.0d0-xOmega1)*(1.0d0-xOmega2)
     1        -xnu32*xnu23*(1.0d0-xOmega2)*(1.0d0-xOmega3)
     2        -xnu13*xnu31*(1.0d0-xOmega1)*(1.0d0-xOmega3)
     3        -2.0d0*xnu12*xnu23*xnu31*(1.0d0-xOmega1)
     4        *(1.0d0-xOmega2)*(1.0d0-xOmega3))

        d11 = e11*(1.0d0-xOmega1)*(1.0d0-xnu23*xnu32*(1.0d0-xOmega2)*
     1             (1.0d0-xOmega3))*xnu
        d22 = e22*(1.0d0-xOmega2)*(1.0d0-xnu13*xnu31*(1.0d0-xOmega1)*
     1             (1.0d0-xOmega3))*xnu 
        d33 = e33*(1.0d0-xOmega3)*(1.0d0-xnu12*xnu21*(1.0d0-xOmega1)*
     1             (1.0d0-xOmega2))*xnu
        d12 = e11*(1.0d0-xOmega1)*(1.0d0-xOmega2)*(xnu21+xnu31*xnu23*
     1             (1.0d0-xOmega3))*xnu
        d13 = e11*(1.0d0-xOmega1)*(1.0d0-xOmega3)*(xnu31+xnu21*xnu32*
     1             (1.0d0-xOmega2))*xnu
        d23 = e22*(1.0d0-xOmega2)*(1.0d0-xOmega3)*(xnu32+xnu12*xnu31*
     1             (1.0d0-xOmega1))*xnu
        d44 = 2.0d0*xmu12*(1.0d0-xOmega4)
        d55 = 2.0d0*xmu23*(1.0d0-xOmega5)
        d66 = 2.0d0*xmu13*(1.0d0-xOmega6)

        trialStress(1) = d11*trialStrain(1)+d12*trialStrain(2)
     1                   +d13*trialStrain(3)
        trialStress(2) = d12*trialStrain(1)+d22*trialStrain(2)
     1                   +d23*trialStrain(3)
        trialStress(3) = d13*trialStrain(1)+d23*trialStrain(2)
     1                   +d33*trialStrain(3)
        trialStress(4) = d44*trialStrain(4)
        trialStress(5) = d55*trialStrain(5)
        trialStress(6) = d66*trialStrain(6)

        DO i = 1,6
            stressNew(k,i) = trialStress(i)
        ENDDO

        ! Energy
        stressPower = half*(
     1              (stressNew(k,1)+stressOld(k,1))*strainInc(k,1)+
     2              (stressNew(k,2)+stressOld(k,2))*strainInc(k,2)+
     3              (stressNew(k,3)+stressOld(k,3))*strainInc(k,3)+
     4              2.0*(stressNew(k,4)+stressOld(k,4))*strainInc(k,4)+
     5              2.0*(stressNew(k,5)+stressOld(k,5))*strainInc(k,5)+
     6              2.0*(stressNew(k,6)+stressOld(k,6))*strainInc(k,6))

        enerInternNew(k) = enerInternOld(k)+stressPower/density(k)

        stateNew(k,7) = rNew1
        stateNew(k,8) = rNew2
        stateNew(k,9) = rNew3
        stateNew(k,10) = rNew4
        stateNew(k,11) = rNew5
        stateNew(k,12) = rNew6
        stateNew(k,13) = xOmega1
        stateNew(k,14) = xOmega2
        stateNew(k,15) = xOmega3
        stateNew(k,16) = xOmega4
        stateNew(k,17) = xOmega5
        stateNew(k,18) = xOmega6

        aminDamage = min(xOmega1,xOmega2,xOmega4)
        stateNew(k,19) = aminDamage

        ! single line if (so no THEN & no ENDIF)
        IF (aminDamage.gt.0.999) stateNew(k,20) = 0.d0

       ENDDO ! this ends the do loop statement at line ~157

      ENDIF ! this ends the if statement at line ~122
      
      RETURN
      END


* <<<<<<<<<<<<<<<<<<<<<< SUBROUTINE FAIL_CLN >>>>>>>>>>>>>>>>>>>>>>>>> *
* *
* Catalanotti failure criteria
* *
* <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> *
      SUBROUTINE FAIL_CLN(trialStress,ST,YT,SL,etaL,etaT,lambda,kappa,
     1                    FI_MT,FI_MC)
        IMPLICIT NONE
        ! input variables
        REAL*8 trialStress(6), ST, YT, SL, etaL, etaT, lambda, kappa
        ! local variables
        REAL*8 a(31), b(31), pi, tN, tT, tL
        REAL*8 trialFI_MT, trialFI_MC, aFail_MC, aFail_MT
        INTEGER i, p
        ! output variables
        REAL*8 FI_MT, FI_MC
       
        pi = 4*atan(1.0d0) ! determine value of pi
        a = (/ (i, i=0,30) /) ! create array of integers from 0 to 30
 
        DO p = 1,31
            b(p) = a(p)*(pi/60) ! create array of angles from 0 to pi/2
        END DO
       
        FI_MT = 0.0d0 ! initialize failure criteria
        FI_MC = 0.0d0

        DO p = 1, 31 ! iterate over angles
            ! Eq 3 CLN (expanded in 59-61)
            tN = trialStress(2)*cos(b(p))**2 + 2.0d0*trialStress(5)
     1          *sin(b(p))*cos(b(p)) + trialStress(3)*sin(b(p))**2
            tT = -1.0*cos(b(p))*sin(b(p))
     1           *(trialStress(2)-trialStress(3))
     2           +(trialStress(5)*(cos(b(p))**2.0 - sin(b(p))**2.0))
            tL = trialStress(4)*cos(b(p)) + trialStress(6)*sin(b(p))
     
            IF (tN.ge.0.0d0) THEN
                trialFI_MT = (tN/ST)**2 + (tL/SL)**2 + (tT/ST)**2 
     1                       + lambda*(tN/ST)*(tL/SL)**2 
     2                       + kappa*(tN/ST) ! Eq. 42 CLN
                trialFI_MC = 0.0
            ELSE
                trialFI_MC = (tL/(SL-etaL*tN))**2 
     1                      + (tT/(ST-etaT*tN))**2 ! Eq. 5 CLN
                trialFI_MT = 0.0
            ENDIF

            IF (trialFI_MT.gt.FI_MT) THEN
                FI_MT = trialFI_MT
                aFail_MT = b(p) ! record failure plane 
            END IF
            IF (trialFI_MC.gt.FI_MC) THEN
                FI_MC = trialFI_MC
                aFail_MC = b(p) ! record failure plane 
            END IF

        END DO

      RETURN
      END  
     
      

* <<<<<<<<<<<<<<<<<<<<<<<<< FUNCTION NEWT >>>>>>>>>>>>>>>>>>>>>>>>>>>> *
* *
* Newton Raphson method to determine miaslignment angle phi
* *
* <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> *
      FUNCTION NEWT(init, trialStress, X)
        REAL*8 NEWT, xOld, xNew, tol, init, df,dx,f, trialStress(6), X
        xOld = init
        xNew = init
        dx = 100
        tol = 0.0001
10      IF (abs(dx).gt.tol) THEN
            xOld = xNew
            dx = FUNC(xOld, trialStress, X)/DFUNC(xOld, trialStress, X)
            xNew = xOld-dx
            GOTO 10
        ELSE
            NEWT = xNew
        END IF
      RETURN
      END

      ! Function used in the Newton Raphson iteration method
      FUNCTION FUNC(gammaOld, trialStress, X)
        REAL*8 FUNC, X, gammaOld, trialStress(6)
        ! Eq. 88 CLN
        FUNC = X*gammaOld + 0.5d0*(trialStress(1) 
     1         - trialStress(2))*sin(2.0d0*gammaOld)
     2         - abs(trialStress(4))*cos(2.0d0*gammaOld) 
      RETURN
      END
  
      ! Derivative function of FUNC
      FUNCTION DFUNC(gammaOld, trialStress, X)
        REAL DFUNC, X, gammaOld, trialStress(6)
        ! Eq. 89 CLN
        DFUNC = X + (trialStress(1)-trialStress(2))*cos(2.0d0*gammaOld)
     1          + 2.0d0*abs(trialStress(4))*sin(2.0d0*gammaOld) 
      RETURN
      END
  
* <<<<<<<<<<<<<<<<<<<<<< SUBROUTINE ROTATE_PHI>>>>>>>>>>>>>>>>>>>>>>>> *
* *
* ROTATION OF STRESSES TO THE MISALIGNMENT COORDINATE FRAME *
* *
* <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> *
      SUBROUTINE ROTATE_PHI(trialStress, phiC, XC, trialStressP)
        IMPLICIT NONE
        ! input variables
        REAL*8 trialStress(6), phiC, XC, NEWT
        ! local variables
        REAL*8 theta, phi, X, m, n, u, v
        REAL*8 trialStressT(6)
        ! output variables
        REAL*8 trialStressP(6)

        ! first determine fracture plane angle theta (fiber kinking)   
        IF ((trialStress(4).eq.0.d0).AND.(trialStress(6).eq.0.d0)) THEN
            IF ((trialStress(2)-trialStress(3)).eq.0.d0) THEN
                theta = atan(1.0d0) ! pi/4
            ELSE
                theta = 0.5d0*atan((2.0d0*trialStress(5))
     1                  /(trialStress(2)-trialStress(3))) !Eq.55 CLN
            ENDIF 
        ELSE
            IF (trialStress(4).eq.0.d0) THEN
                theta = 2.0d0*atan(1.0d0) ! pi/2
            ELSE 
                theta = atan(trialStress(6)/trialStress(4)) !Eq. 56 CLN
            ENDIF
        END IF

        ! determine the misalignment angle phi
        X = (sin(2.0d0*phiC)*XC)/(2.0d0*phiC) ! Eq. 86 CLN

        IF (trialStress(4).gt.0) THEN
            phi = NEWT(0.1, trialStress, X) ! initial value of 0.1
        ELSE 
            phi = -1.0d0*NEWT(0.1, trialStress, X)
        END IF

        m = cos(theta)
        n = sin(theta)
        ! Rotate stresses by angle theta
        trialStressT(1) = trialStress(1)
        trialStressT(2) = trialStress(2)*m**2 
     1                    + 2.0d0*trialStress(5)*m*n 
     2                    + trialStress(3)*n**2
        trialStressT(3) = trialStress(3)*m**2 
     1                    - 2.0d0*trialStress(5)*m*n 
     2                    + trialStress(2)*n**2
        trialStressT(4) = trialStress(4)*m + trialStress(6)*n
        trialStressT(5) = trialStress(5)*(m**2 - n**2)
     1                    - trialStress(2)*n*m 
     2                    + trialStress(3)*n*m
        trialStressT(6) = trialStress(6)*m - trialStress(4)*n

        ! Rotate stresses by angle phi
        u = cos(phi)
        v = sin(phi)
        trialStressP(1) = trialStressT(1)*u**2 
     1                    + 2.0d0*trialStressT(4)*u*v 
     2                    + trialStressT(2)*v**2
        trialStressP(2) = trialStressT(2)*u**2 
     1                    - 2.0d0*trialStressT(4)*v*u 
     2                    + trialStressT(1)*v**2     
        trialStressP(3) = trialStressT(3)      
        trialStressP(4) = trialStressT(4)*(u**2 -v**2) 
     1                    + trialStressT(2)*v*u 
     2                    - trialStressT(1)*v*u
        trialStressP(5) = trialStressT(5)*u - trialStressT(6)*v     
        trialStressP(6) = trialStressT(6)*u + trialStressT(5)*v
        RETURN
        END
  