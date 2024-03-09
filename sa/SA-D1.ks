function st { wait until stage:ready. stage. }
lock Hk to altitude/1000. local H0 is Hk.
lock Vv to verticalspeed.
lock Tc to ship:thrust.
lock Hf to max(0,min(1,(Hk-H0)/(240-H0))).
lock steering to heading(90,90*(1-sqrt(Hf)),0).
wait until Tc>ship:mass*body:mu/body:radius^2. st().
wait until Hk>80 or Vv<0. st().
wait until Hk<40 and Vv<0. st().
