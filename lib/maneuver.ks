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
    "step", mnv_step@,
    "exec", mnv_exec@
  ).

  local e is constant:e.
  local G0 is constant:G0. // converion factor for Isp

  // MANEUVER:STEP()
  // Do a single step adjust of vessel state to meet the
  // needs of the next maneuiver node. Returns how long to
  // wait before calling it again.
  local mnv_step_s is V(0,0,0).
  local mnv_step_t is 0.
  function mnv_step {
    if abort return 0.
    if not hasnode return 0.
    if kuniverse:timewarp:rate>1 return 1.
    if not kuniverse:timewarp:issettled return 1.

    local n is nextnode.
    local v is n:burnvector.

    if 0=mnv_step_t                     set mnv_step_t to time:seconds + n:eta - mnv_time(v:mag)/2.
    if 0=mnv_step_s:mag                 set mnv_step_s to v:normalized.

    local calc_dv is {                  // remaining DV in original thrust direction
      return vdot(mnv_step_s, n:burnvector). }.

    if calc_dv() <= 0 {                  // termination condition
      lock throttle to 0.
      lock steering to facing.
      remove nextnode.
      set mnv_step_s to V(0,0,0).
      set mnv_step_t to 0.
      return 0. }

    // steering setting
    lock steering to lookdirup(mnv_step_s, facing:topvector).

    local th is {         // throttle setting computation
      local wt is mnv_step_t - time:seconds.    if wt > 0 return 0.
      local dv is calc_dv().                    if dv <= 0 return 0.
      local dt is mnv_time(dv).                 if dt >= 1 return 1.
      return sqrt(dt). }.                       lock throttle to th().

    local wt is mnv_step_t - time:seconds.
    if wt>0 and wt<2            return wt.
    if wt>60                    warpto(time:seconds + wt - 30).
    return 1.
  }

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

    if abort return.
    if not hasnode return.

    local n is nextnode.
    local v is n:burnvector.

    local starttime is time:seconds + n:eta - mnv_time(v:mag)/2.
    lock steering to n:burnvector.

    if autowarp { warpto(starttime - 30). }

    wait until time:seconds >= starttime or abort.
    lock throttle to sqrt(max(0,min(1,mnv_time(n:burnvector:mag)))).

    wait until vdot(n:burnvector, v) < 0 or abort.
    lock throttle to 0.
    unlock steering.
    remove nextnode.
    wait 0.
  }

  // MANEUVER:V_E()
  // Compute the aggregate exhaust velocity of the vessel.
  function mnv_v_e {
    list engines in all_engines.
    local num is 0.
    local den is 0.
    for en in all_engines if en:ignition and not en:flameout {
      set num to num + en:availablethrust.
      set den to den + en:availablethrust / en:isp.
    }
    return choose G0 * num / den if den>0 else 0.
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

    return choose M0 * (1 - e^(-dV/v_e)) * v_e / F if v_e>0 else 0.
  }
}
