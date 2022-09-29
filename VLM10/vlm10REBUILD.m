%VLM 10
%Safa Bakhshi
%Set flag to nondimentionalize lift and drag
clear all
NoDimLift = 1;

%Simple Delta(Clipped Tips)
sections =1;
taper = (0.4/20); %Taper Ratio
S = 98; % Reference Area
ARfix = 1; %Aspect Ratio
b = 9.8; %Span
rootC = 20; %Root Chord
alphaIncRoot = 0*(pi/180); %Incidence at Root converted to radians
alphaIncTip = 0*(pi/180); %Incidence at Tip converted to radians
leLambda= 75.5; %Sweep angle 
phi = 0*(pi/180); %Dihedral Angle
data = [taper;rootC;ARfix;leLambda];
camberLine = 0;

Uinf = 1;
%VLM Control: Set panels and modelling options
bPanels = 2;
cPanels = 4; %Chordwise Panels
wakeT = 400; %span lengths for wake termination
dt = (0.041*(rootC)/Uinf)*ones(1,40); %Time Step Vector
wRelaxT = 1; %Factor of Wake Relaxation
wRelaxS = 1;
vS = 0;
Lfac = 1-vS;
Tfac = vS;

%Freestream Control: Set alpha,beta, and leading edge panels for suction
%analogy, Uinf, and rho
alpha = 20*(pi/180); % Angle of attack in degrees/converted to Radians 
beta = 0*(pi/180); %Sideslip angle in degrees/converted to Radians
Uinf =1; %Freestream velocity 
rho =1; %Freestream Density

%Use Geometry Engine to Obtain Panels
[controlPointsY,controlPointsX,panelQuarterC,panelTQuarterC,panelGeomY,panelGeomX,VcontrolPointsX,S,b,N,K,CAve,geomChord,chord] = geomEngine3(sections,data,bPanels,cPanels,'Plot');

realAR = b^2/S;
MAC = (1/S)*trapz(panelGeomY,geomChord.^2);
fprintf('The Aspect Ratio of this Wing is :%f\n',realAR);
fprintf('The Mean Aerodynamic Chord is :%f\n',MAC);
fprintf('The Wing Area is: %f\n',S);

%Set Twist
twist = spline([panelGeomY(1) panelGeomY(length(panelGeomY)/2 +0.5) panelGeomY(end)],[alphaIncTip alphaIncRoot alphaIncTip],controlPointsY);
twist = repmat(twist,cPanels,1);
twist = twist(:);
%Set Wing Camber
[camberDrep,camberMat,camber] = camberFit(camberLine,cPanels,bPanels,N);

%VLM Main Process
%Wake Simulation
vorticityMatrix = zeros(N,N);%K1
vorticityWake = zeros(N,N);%Wake Contributions
vorticitySep = zeros(N,N);%Leading Edge Separation Contributions
%Initialize wake
xw = panelGeomX(end,:);
yw = panelGeomY;
zw = zeros(1,length(panelGeomY));
%Initialize wake history 
xwHis = zeros(length(dt)+1,length(xw));
ywHis = zeros(length(dt)+1,length(yw));
zwHis = zeros(length(dt)+1,length(zw));
xwHis(1,:) = xw;
ywHis(1,:) = yw;
zwHis(1,:) = zw;
%Initialize leading edge separation field
xL = panelGeomX(1,:);
yL = panelGeomY;
zL = zeros(1,length(panelGeomY));
%Initialize leading edge separation history 
xLHis = zeros(length(dt)+1,length(xw));
yLHis = zeros(length(dt)+1,length(yw));
zLHis = zeros(length(dt)+1,length(zw));
xLHis(1,:) = xL;
yLHis(1,:) = yL;
zLHis(1,:) = zL;
%Initilize progress bar
bar = waitbar(0,'Time Progress');


for timeStep = 1:length(dt)
    waitbar(timeStep/length(dt),bar)%Update progress bar

    %Set counters to 1
    panelCount =1;
    contCount =1;   
    
    for i = 1:length(controlPointsY)
        for j = 1:cPanels
            for k = 1:length(controlPointsY)
                for m = 1:cPanels
                    if m == 1
                        Tfac = vS;
                    else
                        Tfac = 1;
                    end
                    f = timeStep;
                    
                    [u1,v1,w1] = VORTEX(-1*(panelGeomX(m,k+1)-panelGeomX(m,k)),panelGeomY(k+1)-panelGeomY(k),0,-1*(panelGeomX(m,k)-controlPointsX(j,i)),panelGeomY(k)-controlPointsY(i),0);
                    
                    %Accumulate Trailing Vortex Sheet and Leading edge
                    %separated vortex contributions
                    %Vortex 2: TE to wake
                    %Vortex 3: wake to TE
                    %Vortex 6: TE to wake
                    %Vortex 7: wake to TE
                    if f ~= 1
                        [u2,v2,w2] = VORTEX(-1*(xwHis(f,k+1) - xwHis(f-1,k+1)),ywHis(f,k+1)-ywHis(f-1,k+1),zwHis(f,k+1)-zwHis(f-1,k+1),...
                            -1*(xwHis(f-1,k+1)-controlPointsX(j,i)),ywHis(f-1,k+1)-controlPointsY(i),zwHis(f-1,k+1));

                        [u3,v3,w3] = VORTEX(-1*(xwHis(f-1,k)- xwHis(f,k)),ywHis(f-1,k)-ywHis(f,k),zwHis(f-1,k)-zwHis(f,k),...
                            -1*(xwHis(f,k)-controlPointsX(j,i)),ywHis(f,k)-controlPointsY(i),zwHis(f,k)); 
                       if m == 1
                        [u6,v6,w6] = VORTEX(-1*(xLHis(f,k+1) - xLHis(f-1,k+1)),yLHis(f,k+1)-yLHis(f-1,k+1),zLHis(f,k+1)-zLHis(f-1,k+1),...
                            -1*(xLHis(f-1,k+1)-controlPointsX(j,i)),yLHis(f-1,k+1)-controlPointsY(i),zLHis(f-1,k+1));

                        [u7,v7,w7] = VORTEX(-1*(xLHis(f-1,k)- xLHis(f,k)),yLHis(f-1,k)-yLHis(f,k),zLHis(f-1,k)-zLHis(f,k),...
                            -1*(xLHis(f,k)-controlPointsX(j,i)),yLHis(f,k)-controlPointsY(i),zLHis(f,k)); 
                       else
                         u6=0;v6=0;w6=0;u7=0;v7=0;w7=0;
                       end
                       
                       if panelCount > N/2
                            vorticityWake(panelCount,contCount) = vorticityWake(panelCount,contCount) + Tfac*(w2+w3)*cos(phi)*cos(atan(camberMat(j,i))) - Tfac*(u2+u3)*sin(atan(camberMat(j,i)))*cos(phi) - Tfac*(v2+v3)*sin(phi);
                            vorticitySep(panelCount,contCount) = vorticitySep(panelCount,contCount) + Lfac*(w6+w7)*cos(phi)*cos(atan(camberMat(j,i))) - Lfac*(u6+u7)*sin(atan(camberMat(j,i)))*cos(phi) - Lfac*(v6+v7)*sin(phi);
                       else
                            vorticityWake(panelCount,contCount) = vorticityWake(panelCount,contCount) + Tfac*(w2+w3)*cos(phi)*cos(atan(camberMat(j,i))) - Tfac*(u2+u3)*sin(atan(camberMat(j,i)))*cos(phi) - Tfac*(v2+v3)*sin(-phi);
                            vorticitySep(panelCount,contCount) = vorticitySep(panelCount,contCount) + Lfac*(w6+w7)*cos(phi)*cos(atan(camberMat(j,i))) - Lfac*(u6+u7)*sin(atan(camberMat(j,i)))*cos(phi) - Lfac*(v6+v7)*sin(-phi);
                       end
                    end
                    
                     %Infinite Addon from last known wake points                       
                    [u2inf,v2inf,w2inf] = VORTEX(wakeT*b - (-1*xwHis(f,k+1)),tan(beta)*(wakeT*b - (-1*xwHis(f,k+1))),tan(alpha/2)*(wakeT*b - (-1*xwHis(f,k+1))),...
                        -1*(xwHis(f,k+1)-controlPointsX(j,i)),ywHis(f,k+1)-controlPointsY(i),zwHis(f,k+1));

                    [u3inf,v3inf,w3inf] = VORTEX((-1*xwHis(f,k))- wakeT*b ,tan(beta)*((-1*xwHis(f,k))- wakeT*b),tan(alpha/2)*((-1*xwHis(f,k))- wakeT*b),...
                        wakeT*b-(-1*controlPointsX(j,i)),ywHis(f,k)+tan(beta)*(wakeT*b - (-1*xwHis(f,k)))-controlPointsY(i),zwHis(f,k)+tan(alpha/2)*(wakeT*b-(-1*xwHis(f,k))));
                    if m==1
                    [u6inf,v6inf,w6inf] = VORTEX(wakeT*b - (-1*xLHis(f,k+1)),tan(beta)*(wakeT*b - (-1*xLHis(f,k+1))),tan(alpha/2)*(wakeT*b - (-1*xLHis(f,k+1))),...
                        -1*(xLHis(f,k+1)-controlPointsX(j,i)),yLHis(f,k+1)-controlPointsY(i),zLHis(f,k+1));

                    [u7inf,v7inf,w7inf] = VORTEX((-1*xLHis(f,k))- wakeT*b ,tan(beta)*((-1*xLHis(f,k))- wakeT*b),tan(alpha/2)*((-1*xLHis(f,k))- wakeT*b),...
                        wakeT*b-(-1*controlPointsX(j,i)),yLHis(f,k)+tan(beta)*(wakeT*b - (-1*xLHis(f,k)))-controlPointsY(i),zLHis(f,k)+tan(alpha/2)*(wakeT*b-(-1*xLHis(f,k))));
                    else
                        u6inf =0;v6inf=0;w6inf=0;u7inf =0;v7inf=0;w7inf=0;
                    end
                    u6inf=Lfac*u6inf; v6inf=Lfac*v6inf; w6inf=Lfac*w6inf; u7inf =Lfac*u7inf; v7inf=Lfac*v7inf; w7inf=Lfac*w7inf;
                    u2inf=Tfac*u2inf; v2inf=Tfac*v2inf; w2inf=Tfac*w2inf; u3inf =Tfac*u3inf; v3inf=Tfac*v3inf; w3inf=Tfac*w3inf;
                    %Trailing Vorticies on the wing
                    %Vortex 4: quarter chord to TE
                    %Vortex 5: TE to quarter chord
                    [u4,v4,w4] = VORTEX((-1*(panelGeomX(end,k+1)) - (-1*panelGeomX(m,k+1))),0,0,-1*(panelGeomX(m,k+1)-controlPointsX(j,i)),panelGeomY(k+1)-controlPointsY(i),0);
                    [u5,v5,w5] = VORTEX((-1*panelGeomX(m,k))- (-1*(panelGeomX(end,k))),0,0,-1*(panelGeomX(end,k)-controlPointsX(j,i)),panelGeomY(k)-controlPointsY(i),0);
                    if m == 1
                        u4=u4*Lfac;v4=v4*Lfac;w4=w4*Lfac;u5=u5*Lfac;v5=v5*Lfac;w5=w5*Lfac;
                    end
     
                    %Sum contributions from each segment in the u,v,w
                    %directions. Excluding the tracked wake.
                    u = u1 + u2inf + u3inf +  u4 + u5;
                    v = v1 + v2inf + v3inf +  v4 + v5; 
                    w = w1 + w2inf + w3inf +  w4 + w5;
                    
                    %Apply effects of camber and dihedral to contributions
                    %before assigning to vorticity matrix. Note
                    %asymmetircal dihedral angle on each wing
                   if panelCount > N/2
                    vorticityMatrix(panelCount,contCount) = vorticityWake(panelCount,contCount) + vorticitySep(panelCount,contCount) + w*cos(phi)*cos(atan(camberMat(j,i))) - u*sin(atan(camberMat(j,i)))*cos(phi) - v*sin(phi);
                   else
                    vorticityMatrix(panelCount,contCount) = vorticityWake(panelCount,contCount) + vorticitySep(panelCount,contCount) + w*cos(phi)*cos(atan(camberMat(j,i))) - u*sin(atan(camberMat(j,i)))*cos(phi) - v*sin(-phi);
                   end
                   contCount = contCount + 1;
                    
                end
            end
            %Update counters
            panelCount = panelCount + 1;
            contCount =1;
        end
    end
    %Generate RHS of matrix equation with no penetration boundary condition.
    %Includes effects from alpha, beta, phi, and camber
    %RHS1 is left wing and RHS2 is right wing
    %Concatinate vectors 
    RHS1 = Uinf*(sin(atan(camberDrep(1:N/2,:)))*cos(phi)*cos(alpha)*cos(beta)+...
        sin(beta)*sin(-phi)...
        -sin(alpha)*cos(beta)*cos(atan(camberDrep(1:N/2,:)))*cos(phi)).*ones(N/2,1);
    RHS2 = Uinf*(sin(atan(camberDrep(N/2+1:end,:)))*cos(phi)*cos(alpha)*cos(beta)+...
        sin(beta)*sin(phi)-...
        sin(alpha)*cos(beta)*cos(atan(camberDrep(N/2+1:end,:)))*cos(phi)).*ones(N/2,1);
    RHS = [RHS1;RHS2];
    
    gamma = linsolve(vorticityMatrix,RHS);
    gammaMatrix = reshape(gamma,cPanels,2*sum(bPanels));
    
    %Wake Tracking Process
    %Reset wake velocity field purturbations
    uw = zeros(1,length(panelGeomY));
    vw = zeros(1,length(panelGeomY));
    ww = zeros(1,length(panelGeomY));
    uL = zeros(1,length(panelGeomY));
    vL = zeros(1,length(panelGeomY));
    wL = zeros(1,length(panelGeomY));
    
    %Track trailing wake
    for i = 1:length(panelGeomY)
        for k = 1:length(controlPointsY)
            for m = 1:cPanels
                if m == 1
                    Tfac = vS;
                else
                    Tfac = 1;
                end
                [u1,v1,w1] = VORTEX(-1*(panelGeomX(m,k+1)-panelGeomX(m,k)),panelGeomY(k+1)-panelGeomY(k),0,-1*(panelGeomX(m,k)-xw(i)),panelGeomY(k)-yw(i),-zw(i));
                u2tot = 0;u3tot=0;u6tot=0;u7tot=0;
                v2tot = 0;v3tot=0;v6tot=0;v7tot=0;
                w2tot = 0;w3tot=0;w6tot=0;w7tot=0;
                for f = 1:timeStep
                    if f ~=1
                    %Vortex 2: TE to wake
                    %Vortex 3: wake to TE 
                    [u2,v2,w2] = VORTEX(-1*(xwHis(f,k+1) - xwHis(f-1,k+1)),ywHis(f,k+1)-ywHis(f-1,k+1),zwHis(f,k+1)-zwHis(f-1,k+1),...
                        -1*(xwHis(f-1,k+1)-xw(i)),ywHis(f-1,k+1)- yw(i),zwHis(f-1,k+1)-zw(i));

                    [u3,v3,w3] = VORTEX(-1*(xwHis(f-1,k)- xwHis(f,k)),ywHis(f-1,k)-ywHis(f,k),zwHis(f-1,k)-zwHis(f,k),...
                        -1*(xwHis(f,k)-xw(i)),ywHis(f,k)- yw(i),zwHis(f,k)-zw(i));  
                    
                    if m == 1
                        [u6,v6,w6] = VORTEX(-1*(xLHis(f,k+1) - xLHis(f-1,k+1)),yLHis(f,k+1)-yLHis(f-1,k+1),zLHis(f,k+1)-zLHis(f-1,k+1),...
                            -1*(xLHis(f-1,k+1)-xw(i)),yLHis(f-1,k+1)- yw(i),zLHis(f-1,k+1)-zw(i));

                        [u7,v7,w7] = VORTEX(-1*(xLHis(f-1,k)- xLHis(f,k)),yLHis(f-1,k)-yLHis(f,k),zLHis(f-1,k)-zLHis(f,k),...
                            -1*(xLHis(f,k)-xw(i)),yLHis(f,k)- yw(i),zLHis(f,k)-zw(i));  
                        u6 =u6*Lfac; v6 =v6*Lfac; w6 =w6*Lfac; u7=u7*Lfac; v7=v7*Lfac; w7=w7*Lfac;
                        u2 =u2*Tfac; v2 =v2*Tfac; w2=w2*Tfac; u3=u3*Tfac; v3=v3*Tfac; w3=w3*Tfac;
                    else
                        u6 =0; v6 =0; w6 =0; u7=0; v7=0; w7=0;
                    end                    
                    u2tot = u2tot + u2; u3tot = u3tot + u3; u6tot = u6tot + u6;u7tot = u7tot + u7;
                    v2tot = v2tot + v2; v3tot = v3tot + v3; v6tot = v6tot + v6;v7tot = v7tot + v7;
                    w2tot = w2tot + w2; w3tot = w3tot + w3; w6tot = w6tot + w6;w7tot = w7tot + w7;
                    end
                    if f == timeStep
                        %Infinite Addon from last known wake points
                        [u2inf,v2inf,w2inf] = VORTEX(wakeT*b - (-1*xwHis(f,k+1)),tan(beta)*(wakeT*b - (-1*xwHis(f,k+1))),tan(alpha)*(wakeT*b - (-1*xwHis(f,k+1))),...
                            -1*(xwHis(f,k+1)-xw(i)),ywHis(f,k+1)-yw(i),zwHis(f,k+1)-zw(i));

                        [u3inf,v3inf,w3inf] = VORTEX((-1*xwHis(f,k))- wakeT*b ,tan(beta)*((-1*xwHis(f,k))- wakeT*b),tan(alpha)*((-1*xwHis(f,k))- wakeT*b),...
                            wakeT*b-(-1*xw(i)),ywHis(f,k)+tan(beta)*(wakeT*b-(-1*xwHis(f,k)))-yw(i),zwHis(f,k)+tan(alpha)*(wakeT*b-(-1*xwHis(f,k)))-zw(i));
                        if m==1
                            [u6inf,v6inf,w6inf] = VORTEX(wakeT*b - (-1*xLHis(f,k+1)),tan(beta)*(wakeT*b - (-1*xLHis(f,k+1))),tan(alpha)*(wakeT*b - (-1*xLHis(f,k+1))),...
                                -1*(xLHis(f,k+1)-xw(i)),yLHis(f,k+1)-yw(i),zLHis(f,k+1)-zw(i));

                            [u7inf,v7inf,w7inf] = VORTEX((-1*xLHis(f,k))- wakeT*b ,tan(beta)*((-1*xLHis(f,k))- wakeT*b),tan(alpha)*((-1*xLHis(f,k))- wakeT*b),...
                                wakeT*b-(-1*xw(i)),yLHis(f,k)+tan(beta)*(wakeT*b-(-1*xLHis(f,k)))-yw(i),zLHis(f,k)+tan(alpha)*(wakeT*b-(-1*xLHis(f,k)))-zw(i));
                             u2inf=Tfac*u2inf; v2inf=Tfac*v2inf; w2inf=Tfac*w2inf; u3inf =Tfac*u3inf; v3inf=Tfac*v3inf; w3inf=Tfac*w3inf;  
                             u6inf=Lfac*u6inf; v6inf=Lfac*v6inf; w6inf=Lfac*w6inf; u7inf =Lfac*u7inf; v7inf=Lfac*v7inf; w7inf=Lfac*w7inf;
                        else
                            u6inf =0;v6inf=0;w6inf=0;u7inf =0;v7inf=0;w7inf=0;
                        end  

                        u2tot = u2tot + u2inf; u3tot = u3tot + u3inf; u6tot = u6tot + u6inf; u7tot = u7tot + u7inf;
                        v2tot = v2tot + v2inf; v3tot = v3tot + v3inf; v6tot = v6tot + v6inf; v7tot = v7tot + v7inf;
                        w2tot = w2tot + w2inf; w3tot = w3tot + w3inf; w6tot = w6tot + w6inf; w7tot = w7tot + w7inf;
                    end                    
                end
                
                %Vortex 4: quarter chord to TE
                %Vortex 5: TE to quarter chord
                if m == 1
                    [u4,v4,w4] = VORTEX((-1*(panelGeomX(end,k+1)) - (-1*panelGeomX(m,k+1))),0,0,-1*(panelGeomX(m,k+1)-xw(i)),panelGeomY(k+1)-yw(i),-zw(i));
                    [u5,v5,w5] = VORTEX((-1*panelGeomX(m,k))- (-1*(panelGeomX(end,k))),0,0,-1*(panelGeomX(end,k)-xw(i)),panelGeomY(k)-yw(i),-zw(i));
                    
                    u4 =Tfac*u4; v4 =Tfac*v4; w4=Tfac*w4; u5=Tfac*u5; v5=Tfac*v5; w5=Tfac*w5;
                else
                    [u4,v4,w4] = VORTEX((-1*(panelGeomX(end,k+1)) - (-1*panelGeomX(m,k+1))),0,0,-1*(panelGeomX(m,k+1)-xw(i)),panelGeomY(k+1)-yw(i),-zw(i));
                    [u5,v5,w5] = VORTEX((-1*panelGeomX(m,k))- (-1*(panelGeomX(end,k))),0,0,-1*(panelGeomX(end,k)-xw(i)),panelGeomY(k)-yw(i),-zw(i));
                end    
                 %Sum contributions from each segment in the u,v,w
                %directions. Include factor of relaxation here

                uw(i) = uw(i) + wRelaxS*gammaMatrix(m,k)*(u1 + u2tot + u3tot + u4 + u5 + u6tot + u7tot);
                vw(i) = vw(i) + wRelaxS*gammaMatrix(m,k)*(v1 + v2tot + v3tot + v4 + v5 + v6tot + v7tot); 
                ww(i) = ww(i) + wRelaxS*gammaMatrix(m,k)*(w1 + w2tot + w3tot + w4 + w5 + w6tot + w7tot);  
            end
        end
    end
    
    %Track leading wake
    for i = 1:length(panelGeomY)
        for k = 1:length(controlPointsY)
            for m = 1:cPanels
                if m == 1
                    Tfac = vS;
                else
                    Tfac = 1;
                end
                [u1,v1,w1] = VORTEX(-1*(panelGeomX(m,k+1)-panelGeomX(m,k)),panelGeomY(k+1)-panelGeomY(k),0,-1*(panelGeomX(m,k)-xL(i)),panelGeomY(k)-yL(i),-zL(i));
                u2tot = 0;u3tot=0;u6tot=0;u7tot=0;
                v2tot = 0;v3tot=0;v6tot=0;v7tot=0;
                w2tot = 0;w3tot=0;w6tot=0;w7tot=0;
                for f = 1:timeStep
                    if f ~=1
                    %Vortex 2: TE to wake
                    %Vortex 3: wake to TE 
                    [u2,v2,w2] = VORTEX(-1*(xwHis(f,k+1) - xwHis(f-1,k+1)),ywHis(f,k+1)-ywHis(f-1,k+1),zwHis(f,k+1)-zwHis(f-1,k+1),...
                        -1*(xwHis(f-1,k+1)-xL(i)),ywHis(f-1,k+1)- yL(i),zwHis(f-1,k+1)-zL(i));

                    [u3,v3,w3] = VORTEX(-1*(xwHis(f-1,k)- xwHis(f,k)),ywHis(f-1,k)-ywHis(f,k),zwHis(f-1,k)-zwHis(f,k),...
                        -1*(xwHis(f,k)-xL(i)),ywHis(f,k)- yL(i),zwHis(f,k)-zL(i));  
                    
                    if m == 1
                        [u6,v6,w6] = VORTEX(-1*(xLHis(f,k+1) - xLHis(f-1,k+1)),yLHis(f,k+1)-yLHis(f-1,k+1),zLHis(f,k+1)-zLHis(f-1,k+1),...
                            -1*(xLHis(f-1,k+1)-xL(i)),yLHis(f-1,k+1)- yL(i),zLHis(f-1,k+1)-zL(i));

                        [u7,v7,w7] = VORTEX(-1*(xLHis(f-1,k)- xLHis(f,k)),yLHis(f-1,k)-yLHis(f,k),zLHis(f-1,k)-zLHis(f,k),...
                            -1*(xLHis(f,k)-xL(i)),yLHis(f,k)- yL(i),zLHis(f,k)-zL(i));  
                        u6 =u6*Lfac; v6 =v6*Lfac; w6 =w6*Lfac; u7=u7*Lfac; v7=v7*Lfac; w7=w7*Lfac;
                        u2 =u2*Tfac; v2 =v2*Tfac; w2=w2*Tfac; u3=u3*Tfac; v3=v3*Tfac; w3=w3*Tfac;
                    else
                        u6 =0; v6 =0; w6 =0; u7=0; v7=0; w7=0;
                    end                    
                    u2tot = u2tot + u2; u3tot = u3tot + u3; u6tot = u6tot + u6;u7tot = u7tot + u7;
                    v2tot = v2tot + v2; v3tot = v3tot + v3; v6tot = v6tot + v6;v7tot = v7tot + v7;
                    w2tot = w2tot + w2; w3tot = w3tot + w3; w6tot = w6tot + w6;w7tot = w7tot + w7;
                    end
                    if f == timeStep
                        %Infinite Addon from last known wake points
                        [u2inf,v2inf,w2inf] = VORTEX(wakeT*b - (-1*xwHis(f,k+1)),tan(beta)*(wakeT*b - (-1*xwHis(f,k+1))),tan(alpha)*(wakeT*b - (-1*xwHis(f,k+1))),...
                            -1*(xwHis(f,k+1)-xL(i)),ywHis(f,k+1)-yL(i),zwHis(f,k+1)-zL(i));

                        [u3inf,v3inf,w3inf] = VORTEX((-1*xwHis(f,k))- wakeT*b ,tan(beta)*((-1*xwHis(f,k))- wakeT*b),tan(alpha)*((-1*xwHis(f,k))- wakeT*b),...
                            wakeT*b-(-1*xL(i)),ywHis(f,k)+tan(beta)*(wakeT*b-(-1*xwHis(f,k)))-yL(i),zwHis(f,k)+tan(alpha)*(wakeT*b-(-1*xwHis(f,k)))-zL(i));
                        if m==1
                            [u6inf,v6inf,w6inf] = VORTEX(wakeT*b - (-1*xLHis(f,k+1)),tan(beta)*(wakeT*b - (-1*xLHis(f,k+1))),tan(alpha)*(wakeT*b - (-1*xLHis(f,k+1))),...
                                -1*(xLHis(f,k+1)-xL(i)),yLHis(f,k+1)-yL(i),zLHis(f,k+1)-zL(i));

                            [u7inf,v7inf,w7inf] = VORTEX((-1*xLHis(f,k))- wakeT*b ,tan(beta)*((-1*xLHis(f,k))- wakeT*b),tan(alpha)*((-1*xLHis(f,k))- wakeT*b),...
                                wakeT*b-(-1*xL(i)),yLHis(f,k)+tan(beta)*(wakeT*b-(-1*xLHis(f,k)))-yL(i),zLHis(f,k)+tan(alpha)*(wakeT*b-(-1*xLHis(f,k)))-zL(i));
                             u2inf=Tfac*u2inf; v2inf=Tfac*v2inf; w2inf=Tfac*w2inf; u3inf =Tfac*u3inf; v3inf=Tfac*v3inf; w3inf=Tfac*w3inf;  
                             u6inf=Lfac*u6inf; v6inf=Lfac*v6inf; w6inf=Lfac*w6inf; u7inf =Lfac*u7inf; v7inf=Lfac*v7inf; w7inf=Lfac*w7inf;
                        else
                            u6inf =0;v6inf=0;w6inf=0;u7inf =0;v7inf=0;w7inf=0;
                        end  

                        u2tot = u2tot + u2inf; u3tot = u3tot + u3inf; u6tot = u6tot + u6inf; u7tot = u7tot + u7inf;
                        v2tot = v2tot + v2inf; v3tot = v3tot + v3inf; v6tot = v6tot + v6inf; v7tot = v7tot + v7inf;
                        w2tot = w2tot + w2inf; w3tot = w3tot + w3inf; w6tot = w6tot + w6inf; w7tot = w7tot + w7inf;
                    end                    
                end
                
                %Vortex 4: quarter chord to TE
                %Vortex 5: TE to quarter chord
                if m == 1
                    [u4,v4,w4] = VORTEX((-1*(panelGeomX(end,k+1)) - (-1*panelGeomX(m,k+1))),0,0,-1*(panelGeomX(m,k+1)-xL(i)),panelGeomY(k+1)-yL(i),-zL(i));
                    [u5,v5,w5] = VORTEX((-1*panelGeomX(m,k))- (-1*(panelGeomX(end,k))),0,0,-1*(panelGeomX(end,k)-xL(i)),panelGeomY(k)-yL(i),-zL(i));
                    
                    u4 =Tfac*u4; v4 =Tfac*v4; w4=Tfac*w4; u5=Tfac*u5; v5=Tfac*v5; w5=Tfac*w5;
                else
                    [u4,v4,w4] = VORTEX((-1*(panelGeomX(end,k+1)) - (-1*panelGeomX(m,k+1))),0,0,-1*(panelGeomX(m,k+1)-xL(i)),panelGeomY(k+1)-yL(i),-zL(i));
                    [u5,v5,w5] = VORTEX((-1*panelGeomX(m,k))- (-1*(panelGeomX(end,k))),0,0,-1*(panelGeomX(end,k)-xL(i)),panelGeomY(k)-yL(i),-zL(i));
                end    
                 %Sum contributions from each segment in the u,v,w
                %directions. Include factor of relaxation here

                uL(i) = uL(i) + wRelaxS*gammaMatrix(m,k)*(u1 + u2tot + u3tot + u4 + u5 + u6tot + u7tot);
                vL(i) = vL(i) + wRelaxS*gammaMatrix(m,k)*(v1 + v2tot + v3tot + v4 + v5 + v6tot + v7tot); 
                wL(i) = wL(i) + wRelaxS*gammaMatrix(m,k)*(w1 + w2tot + w3tot + w4 + w5 + w6tot + w7tot);  
            end
        end
    end
    
    %Use Forward Euler to advance one time step and obtain the K1 term
    xwK1 = -dt(timeStep)*(uw + Uinf*cos(alpha)*cos(beta));
    ywK1 = dt(timeStep)*(vw + Uinf*cos(alpha)*sin(beta));
    zwK1 = dt(timeStep)*(ww + Uinf*sin(alpha));
    xLK1 = -dt(timeStep)*(uL + Uinf*cos(alpha)*cos(beta));
    yLK1 = dt(timeStep)*(vL + Uinf*cos(alpha)*sin(beta));
    zLK1 = dt(timeStep)*(wL + Uinf*sin(alpha));
 
%     xwK1 = -dt(timeStep)*(Uinf*cos(alpha)*cos(beta));
%     ywK1 = (vw*(xwK1)/(Uinf+uw));
%     zwK1 = (ww*(xwK1)/(Uinf+uw));
%     xLK1 = -dt(timeStep)*(Uinf*cos(alpha)*cos(beta));
%     yLK1 = (vL*(xLK1)/(Uinf+uL));
%     zLK1 = (wL*(xLK1)/(Uinf+uL));
    
    
    %Solver 1: Forward Euler
    % Apply solver to track next wake location
    xw = xw + (xwK1);
    yw = yw + (ywK1);
    zw = zw + (zwK1);
    xL = xL + xLK1;
    yL = yL + yLK1;
    zL = zL + zLK1;
    
    %Update wake position history
    xwHis(timeStep+1,:) = xw;
    ywHis(timeStep+1,:) = yw;
    zwHis(timeStep+1,:) = zw;
    xLHis(timeStep+1,:) = xL;
    yLHis(timeStep+1,:) = yL;
    zLHis(timeStep+1,:) = zL;  
    
    
end

%This section of code breaks the gammaMatrix back into sections 
%by identifying start and ends points of each section in the matrix
sPoints = zeros(2,sections);
ePoints = zeros(2,sections);
for i = 1:sections
    sPoints(1,i) = 1 + sum(bPanels(sections:-1:i))-bPanels(i);
    sPoints(2,i) = sPoints(1,i) + sum(bPanels(1:i))+sum(bPanels(1:i-1));

    ePoints(1,i) = sPoints(1,i) + bPanels(i)-1;
    ePoints(2,i) = sPoints(2,i) + bPanels(i)-1;
end
%Use the start and end points to apply Kutta-Joukowski to each section
%with the appropriate width(K) of each section
for t = 1:sections
          potentialLiftDist(:,[sPoints(1,t):ePoints(1,t),sPoints(2,t):ePoints(2,t)])  = ...
              rho*Uinf*gammaMatrix(:,[sPoints(1,t):ePoints(1,t),sPoints(2,t):ePoints(2,t)])*K(t);

end

% In order to apply the Kutta-Joukowski the bound vortices are projected
% normal to the freestream. NOTE: Sweep is already accounted for in the panel width K from
% geomEngine.m
for cPan = 1:cPanels
    potentialLiftDist(cPan,1:bPanels) = potentialLiftDist(cPan,1:bPanels)*cos(-beta);
    potentialLiftDist(cPan,bPanels+1:end) = potentialLiftDist(cPan,bPanels+1:end)*cos(beta);
end

%Plotting Section

%Plot Wing Descretization with horseshoe vortices and wake
wakeTPlot = wakeT*b/100;
drawSim3(controlPointsY,controlPointsX,panelQuarterC,panelGeomY,panelGeomX,alpha,beta,wakeTPlot,xwHis,ywHis,zwHis,xLHis,yLHis,zLHis,dt,bPanels,cPanels,MAC,'freeWake','NOanimate');

%Plot Panel Geometry and Control Points
%Create a Y coordinate matrix for the contour plot
bigY = zeros(cPanels,2*sum(bPanels));
for n = 1:cPanels
    bigY(n,:) = controlPointsY;
end

%Plot a total lift contour plot
figure()
contourf(bigY,VcontrolPointsX,potentialLiftDist,90,'linecolor','none')
colorbar
title('Total lift distribution of planform');
xlabel('y');
ylabel('-x');
colormap jet

%Calculate spanwise lift and drag distributions by summing each column of the
%lift and drag contours
potliftDistribution = sum(potentialLiftDist);


%Divide by K to obtain the lift per unit span
for t = 1:sections
          spanwiseTotalLiftDist([sPoints(1,t):ePoints(1,t),sPoints(2,t):ePoints(2,t)])  = ...
              potliftDistribution([sPoints(1,t):ePoints(1,t),sPoints(2,t):ePoints(2,t)])/K(t);
end

% Plot spanwise total Lift distribution
figure()
if NoDimLift == 1
    plot([-b/2 controlPointsY b/2],[0 spanwiseTotalLiftDist/(.5*Uinf^2*rho*CAve) 0])
    title('Calculated spanwise Total Lift distribution');
    xlabel('y')
    ylabel('L''/q C_ave');
else
    plot([-b/2 controlPointsY b/2],[0 spanwiseTotalLiftDist 0])
    title('Calculated spanwise Total Lift distribution');
    xlabel('y')
    ylabel('L''');
end


%Calculate and Print Coefficients
LiftPot = sum(potliftDistribution);
CLPot = 2*LiftPot/(rho*S*Uinf^2);
fprintf('CL = %f\n',CLPot);

% Function to calculate 
function [u,v,w] = VORTEX(Gx, Gy, Gz, Rx, Ry, Rz)
%Vortex Root at Origin
x1n = 0;
y1n = 0;
z1n = 0;

%Vortex Tip Location
x2n = Gx;
y2n = Gy;
z2n = Gz;

% Set Control Point location

%Convention 2: Kroo convention(Vortex Root minus Control Point)
x = -Rx;
y = -Ry;
z = -Rz;

% 
G2=Gx*Gx+Gy*Gy+Gz*Gz;
R2=Rx*Rx+Ry*Ry+Rz*Rz;
E2=(Gx+Rx)*(Gx+Rx)+(Gy+Ry)*(Gy+Ry)+(Gz+Rz)*(Gz+Rz);
R1Length = sqrt(R2);
GLength = sqrt(G2);
R2Length = sqrt(E2);
spp = (R1Length+GLength+R2Length)/2;
h = 2*sqrt(spp*(spp-R1Length)*(spp-GLength)*(spp-R2Length))/GLength;

% h = norm(cross([Rx,Ry,Rz],[Gx,Gy,Gz]))/norm([Gx,Gy,Gz]);
RC = 20;
if h < (1E-6*RC)
% if h < sqrt(4*.001*timeGlobal)
    u=0.0;
    v=0.0;
    w=0.0;
else
    %R1 X R2
    R1XR2x = 1*((y-y1n)*(z-z2n)-(y-y2n)*(z-z1n));
    R1XR2y = -1*((x-x1n)*(z-z2n)-(x-x2n)*(z-z1n));
    R1XR2z = 1*((x-x1n)*(y-y2n)-(x-x2n)*(y-y1n));

    %|R1 X R2|
    R1XR2 = R1XR2x^2 + R1XR2y^2 + R1XR2z^2;

    %sigma: see Virginia Tech textbook ch 6 pg. 18
    sig1 = ( (x2n-x1n)*(x-x1n) + (y2n-y1n)*(y-y1n) + (z2n-z1n)*(z-z1n))/...
        sqrt((x-x1n)^2 + (y-y1n)^2 + (z-z1n)^2);
    sig2 = ( (x2n-x1n)*(x-x2n) + (y2n-y1n)*(y-y2n) + (z2n-z1n)*(z-z2n))/...
        sqrt((x-x2n)^2 + (y-y2n)^2 + (z-z2n)^2);

    V = (sig1-sig2) / (4.0*pi);
    u = V*(R1XR2x/R1XR2);
    v = V*(R1XR2y/R1XR2);
    w = V*(R1XR2z/R1XR2);
end

end

