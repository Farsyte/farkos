// Package "CoastU" -- Coast Upward to Apoapsis
export({ parameter margin.

  // coastu(margin) -- coast until near apoapsis.
  //
  // return when we are less than margin seconds from apoapsis,
  // or immediately if we are descending.

  lock Ct to 0. lock Cs to prograde.
  lock steering to Cs. lock throttle to Ct. rcs off.
  wait until eta:apoapsis < margin or ship:verticalspeed < 0.
}).
