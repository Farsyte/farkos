// Package "launch" -- Launch Phase
local farkos is import("farkos").

// uses the "setstage" package to arrange for automatic staging.
// importing setstage first, then deleting the source file, was
// required to minimize the local storage needed during startup.
local ss is import("setstage").
deletepath("setstage.ksm").

// launch:go(launch_azimuth) -- launch
//
// Execute the launch profile.
// - wait for pilot to initiate the launch
// - at 10 m/s, rotate craft to match launch azimuth
// - initiate the automatic staging facility
// - at 100 m/s, phase is complete.
export({ parameter launch_azimuth.

  set Ct to 1. set Cs to facing.
  unlock steering. unlock throttle.

  if availablethrust <= 0
    farkos:ev("push GO to launch").
  wait until availablethrust > 0.

  farkos:ev("launch ...").
  lock steering to Cs. lock throttle to Ct.
  wait until ship:velocity:surface:mag > 10.
  lock Cs to heading(launch_azimuth, 90).

  ss:go().
  runpath("auto_stage.ks",ss).
  deletepath("auto_stage.ks").

  wait until ship:velocity:surface:mag > 100.
}).
