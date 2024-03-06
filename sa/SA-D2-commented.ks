@LAZYGLOBAL off.

// Flight Control for Downrange Rockets:
// - main stage is a liquid fueled engine.
// - we have some attitude control.
// - we have no throttle control.
// - we have a camera inside petal cowlings.
// - payload separates and parachutes down.

// When minimizing the code to fit in very limited storage,
// discard the AoA limiter, the roll inhibiter, and the
// handling of engine failures.

// Wait until all of the world exists. Until we do this, it is best to
// not rely on any data about the vessel other than its name.

wait until ship:unpacked.

// CONFIGURATION

local Hmin is altitude+40.          // CONFIG: start altitude for pitch program
local Hmax is 240000.               // CONFIG: final altitude for pitch program

// Lock controls for launch.

local ascent_attitude is lookdirup(up:vector, facing:topvector).
lock steering to ascent_attitude.
lock throttle to 1.

// FLIGHT ENGINEER MUST HIT SPACE BAR TO START FLIGHT.
// This allows the engineer to run final checks and
// arrange displays appropriately.
//
// This will ignite the engine and start thrust building.
//
// When thrust is sufficient to lift us from the pad,
// release the launch clamps.

local thrust_wanted is ship:mass * body:mu / body:radius^2.
wait until (ship:thrust>thrust_wanted) and stage:ready. stage.

// Initiate the pitch program.
// - directly upward at or below Hmin
// - horizontal (east) at or above Hmax
// - smoothly rotating during the flight
// - limit angle of attack to ±5°
// - do not command changes in roll.

lock altitude_fraction to clamp(0,1,(altitude-Hmin)/(Hmax-Hmin)).
lock pitch_wanted to 90*(1 - sqrt(altitude_fraction)).
lock pitch_current to 90-vang(up:vector,velocity:surface).
lock pitch_command to clamp(pitch_current-5,pitch_current+5,pitch_wanted).
lock dir_steering to heading(90,pitch_command,0).
lock steering to lookdirup(dir_steering:vector, facing:topvector).

wait until ship:thrust <= 0. unlock throttle. unlock steering.

// When we reach 80 km -- or if we start descending early due to an
// engine failure -- separate the avionics payload from the engine and
// the (nearly) empty tank.

wait until (altitude>80000 or verticalspeed<0) and stage:ready. stage.

// Open the petals when ascending through 101km, and close them when
// descending through 99km. Handle the "does not reach 101km" case.
// Also, note that once we have triggered opening the petals, make
// sure enough time passes for them to completely open before trying
// to command them closed again.
//
// These lines can be removed if you do not have a camera, and are
// removed in the minimized D-2.ks file.

wait until (altitude>101000 or verticalspeed<0). if altitude>101000 {
    lights on. wait 10. wait until altitude<99000. lights off. }

// Arm the parachutes when we are below 40km and descending.
wait until (altitude<40000 and verticalspeed<0) and stage:ready. stage.
