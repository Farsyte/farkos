// Maneuver Library v0.1.0
// Kevin Gisi
// http://youtube.com/gisikw
//
// maneuver.ks is his version 0.1.0 of that package,
// as seen in Episode 039 and recorded in Github
// at https://github.com/gisikw/ksprogramming.git
// in episodes/e039/maneuver.v0.1.0.ks
//
// Changes:
// - added attribution comment above
// - added limited documentation of the API
// - added mnv_time to the export list.
// - refactor isp computation out of mnv_time
// - correct Isp computation for non-identical engines
// - compute aggregate exhaust velocity using g₀
// - removed staging logic (see PHASES:BG_STAGER)

{
  global maneuver is lex(
    "time", mnv_time@,
    "v_e", mnv_v_e@,
    "exec", mnv_exec@
  ).

  local e is constant:e.
  local G0 is constant:G0. // converion factor for Isp

  // MANEUVER:EXEC(autowarp)
  //   autowarp         if true, autowarp to the node.
  //
  // The MNV_EXEC method performs the burn described in the next
  // maneuver node. Essentially, steer parallel to the direction
  // of thrust in the node, and maintain an appropriate throttle
  // until the remaining burn vector no longer has any component
  // in the direction of the original.
  //
  function mnv_exec {
    parameter autowarp is false.

    if not hasnode return.

    local n is nextnode.
    local v is n:burnvector.

    local starttime is time:seconds + n:eta - mnv_time(v:mag)/2.
    lock steering to n:burnvector.

    if autowarp { warpto(starttime - 30). }

    wait until time:seconds >= starttime.
    lock throttle to sqrt(max(0,min(1,mnv_time(n:burnvector:mag)))).

    wait until vdot(n:burnvector, v) < 0.
    lock throttle to 0.
    unlock steering.
    remove nextnode.
    wait 0.
  }

  // MANEUVER:V_E()
  // Compute the aggregate exhaust velocity of the vessel.
  function mnv_v_e {
    list engines in all_engines.
    local sum is 0.
    for en in all_engines if en:ignition and not en:flameout
      set sum to sum + en:availablethrust / en:isp.
    return G0 * availablethrust / sum.
  }

  // MANEUVER:TIME(dv)
  //   dv               change in velocity
  //
  // Applies the Rocket Equation to determine the duration
  // of a burn would be (from the current SHIP configuration)
  // to achieve the given change in velocity.
  //
  function mnv_time {
    parameter dV.

    local v_e is mnv_v_e().
    local M0 is ship:mass.
    local F is availablethrust.

    return M0 * (1 - e^(-dV/v_e)) * v_e / F.
  }
}
