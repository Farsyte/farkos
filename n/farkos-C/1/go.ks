local farkos is import("farkos").

local term is import("term").
local launch is import("launch").
local ascend is import("ascend").
local coastu is import("coastu").
local circ is import("circ").

local launch_azimuth is 90.
local orbit_altitude is 72000.

export({
    term(16,64).

    launch(launch_azimuth).
    ascend(launch_azimuth, orbit_altitude).
    coastu(30).
    circ(5,5,1,0.1).

    // at this point, we are DRY.
    lock steering to retrograde.
    wait until stage:ready. stage.

    wait until altitude < 4000.
    lock steering to up.
    wait until stage:ready. stage.
    wait until false.
}).