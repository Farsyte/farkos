// Package "CoastU" -- Coast Upward to Apoapsis
local farkos is import("farkos").
export({ parameter margin.

  // coastu(margin) -- coast until near apoapsis.
  //
  // return when we are less than margin seconds from apoapsis,
  // or immediately if we are descending.

  lock Ct to 0. lock Cs to prograde.
  lock steering to Cs. lock throttle to Ct. rcs off.
  wait until eta:apoapsis < margin or ship:verticalspeed < 0.

  local vs is ship:verticalspeed.
  farkos:ev("coast to apoapsis complete:").
  if vs < 0 {
    farkos:ev("  DESCENDING at " + -round(vs,1) + " m/s").
  } else {
    farkos:ev("  ascending at " + round(vs,1) + " m/s").
    farkos:ev("  apoapsis eta: " + round(eta:apoapsis,1) + " seconds").
  }
}).
