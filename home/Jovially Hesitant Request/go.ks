say("PROJECT: Jovially Hesitant Request").
say("Purpose: Tourists to Space").

loadfile("mission").
loadfile("phases").

lock steering to facing.

mission_bg(bg_stager@).

local launch_azimuth is persist_get("launch_azimuth", 90, true).
local launch_altitude is persist_get("launch_altitude", 80_000, true).

mission_add(LIST(
    "PREFLIGHT",    { // wait for flight engineer to initiate flight with SPACE.
        if availablethrust>0 return 0.
        lock steering to facing.
        lock throttle to 1.
        return 1/10. },
    "LAUNCH",       { // wait for the rocket to get clear of the launch site.
        if alt:radar>50 return 0.
        lock steering to facing.
        lock throttle to 1.
        return 1/10. },
    "ASCENT",       { // until we start descending, gravity turn to the east.
        if apoapsis>launch_altitude return 0.
        lock Af to altitude/launch_altitude.
        lock Cp to 90*(1-sqrt(Af)).
        lock Cb to heading(launch_azimuth,0,0):vector*10.
        lock Ch to VXCL(up:vector,velocity:surface + Cb).
        lock Cv to Ch:normalized*cos(Cp)+up:vector*sin(Cp).
        lock Cs to lookdirup(Cv,up:vector).
        lock steering to Cs.
        lock throttle to 1.
        return 1. },
    "ASCENT",       { // until we leave atmosphere, coast pointing into the wind.
        if verticalspeed<=0 return 0.
        if altitude>body:atm:height return 0.
        lock steering to lookdirup(srfprograde:vector,up:vector).
        lock throttle to 0.
        return 1. },
    "SPACE",        { // while we are in space, coast pointing up.
        if altitude<70000 return 0.
        lock steering to lookdirup(up:vector,facing:upvector).
        lock throttle to 0.
        return 1. },
    "DESCENT",      { // until we are safe to deploy the chute, hold descent attitude.
        if alt:radar<3000 and airspeed<300 return 0.
        lock steering to srfretrograde.
        lock throttle to 0.
        return 1. },
    "PARACHUTES",   { // until we have only stage zero remaining, stage (deploy parachutes).
        if stage:number<1 return 0.
        lock steering to heading(launch_azimuth, 90).
        if stage:ready stage.
        return 1. },
    "LANDING",      { // until we stop descending, keep the nose pointed directly up.
        if verticalspeed >= 0 return 0.
        lock steering to heading(launch_azimuth, 90).
        return 1. },
    "PARKING",      { // until the cows come home, keep the capsule upright.
        lock steering to heading(launch_azimuth, 90).
        return 10. }
    )).

mission_bg({
    if mission_phase()>0 return -1.
    say("Press SPACE to launch.", false).
    return 5.
}).

mission_fg().
wait until false.