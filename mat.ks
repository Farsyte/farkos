clearvecdraws().

set xdir to solarprimevector.
set ydir to body:north:vector.
set zdir to vcrs(xdir,ydir).

set target_lon to 258.7.
set target_apo to 14443787.

set target_AN to xdir*cos(target_lon)*target_apo + zdir*sin(target_lon)*target_apo.
set launch_UP to up:vector*target_apo.

set drawfrom to body:position.

set vmag to 10000000.

set xpAxis to VECDRAWARGS( drawfrom, xdir * vmag, RGB(1.0,0.5,0.5), "Prime Meridian", 1, TRUE ).
// set ypAxis to VECDRAWARGS( drawfrom, ydir * vmag, RGB(0.5,1.0,0.5), "+Y axis", 1, TRUE ).
// set zpAxis to VECDRAWARGS( drawfrom, zdir * vmag, RGB(0.5,0.5,1.0), "+Z axis", 1, TRUE ).

// set xnAxis to VECDRAWARGS( drawfrom, -xdir * vmag, RGB(1.0,0.5,0.5), "-X axis", 1, TRUE ).
// set ynAxis to VECDRAWARGS( drawfrom, -ydir * vmag, RGB(0.5,1.0,0.5), "-Y axis", 1, TRUE ).
// set znAxis to VECDRAWARGS( drawfrom, -zdir * vmag, RGB(0.5,0.5,1.0), "-Z axis", 1, TRUE ).

set target_AN_drawn to VECDRAWARGS( drawfrom, target_AN,
    RGB(1.0,1.0,1.0), "Target AN", 1, TRUE ).

set launch_UP_drawn to VECDRAWARGS( drawfrom, launch_UP,
    RGB(1.0,1.0,1.0), "Launch UP", 1, TRUE ).

wait until false.

set target_lon to 258.7.
set target_apo to 14443787.
set bodyaxis to body:north:vector.
set lon_000e to solarprimevector.
set lon_090e to vcrs(lon_000e,bodyaxis).

set drawfrom to V(0,0,0).

set target_an to target_apo * (
        lon_000e*cos(target_lon) +
        lon_090e*sin(target_lon)).

clearvecdraws().
set v to vecdraw(drawfrom, target_an).
print "v is "+v.
wait until false.
