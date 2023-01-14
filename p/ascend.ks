// Package "ascent" -- Ascent Phase
local farkos is import("farkos").
export({ parameter launch_azimuth, orbit_altitude.

  // ascend:go(launch_azimuth, orbit_altitude) -- launch
  //
  // Execute the ascent profile.
  // - launch profile must be complete.
  // - follow the pitch-over profile below
  // - while in pitch over, lock heading to the launch azimuth.
  // - phase complete when apoapsis exceeds target apoapsis by 1km
  // on completion, cut throttle and command prograde for 10 seconds.
  //
  // The pitch-over profile attempts to follow a curve where the
  // target pitch in degrees is:
  //    88.963 - 115.23935 a^0.4095114 [use zero when this result is negative]
  // where "a" is the radar altitude as a fraction of the orbit altitude;
  // the numerical parameters came from CheersKevin who ran a number
  // of interesting experiments.
  //
  // TODO adjust direction to follow a great circle (in orbital space) with
  // initial launch azimuth, rather than potentially tracking a spiral.


  // we can enter this at any time after launch completes,
  // and will attempt a gravity turn to the given altitude.

  if ship:apoapsis > orbit_altitude
    return.

  set Cs to prograde. set Ct to 1.
  lock steering to Cs. lock throttle to Ct.

  until ship:apoapsis > orbit_altitude + 1000 {

    set pct_alt to alt:radar / orbit_altitude.
    set pitch to min(89, max(0, 90 - 120 * sqrt(pct_alt))).

    // we want to thrust along our current orbit at the selected pitch.
    // just in case we have not yet established any horizontal velocity,
    // add in some speed in the desired direction. once we pitch over we
    // will quickly have the actual velocity dominate.

    set Th to VXCL(UP:VECTOR,velocity:surface+heading(launch_azimuth,0,0):vector*50).
    set Td to Th*cos(pitch)/Th:mag + UP:Vector*sin(pitch).
    set Cs to LOOKDIRUP(Td,facing:topvector).
    wait 0.1.
  }

  farkos:ev("meco at " + round(altitude/1000,1) + " km").

  lock Cs to prograde. set Ct to 0.
  wait 5.
  unlock steering. unlock throttle.
}).
