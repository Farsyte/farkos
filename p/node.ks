{ export(lex("mx",mx@,"mt",mt@)).

  local e is constant:e.

  // mx(aW): execute next node.
  // NOTE: does not use an error controller,
  // results will be approximate.
  function mx {
    local n is nextnode.
    local v0 is n:burnvector.

    local mt is maxthrust.

    if maxthrust <= 0 {
      print "mx: no thrust available.".
      return.
    }

    // maneuver time computations based on
    // code constructed by CheersKevin in
    // his KSProgramming series. Episode 45
    // seems to have the best copy. I modifed
    // the Isp computation and refactored a bit.
    //
    // using LOCK..TO rather than a loop with a wait
    // to assure maximal smoothness of control.

    local mu is ship:orbit:body:mu.
    local r0 is ship:obt:body:radius.
    local g is mu/r0^2.
    local gisp is g * isp().
    local mgispm is ship:mass * gisp / mt.

    LOCK LOCKED_DV to v0:mag. // will change as we burn.
    LOCK LOCKED_XF to 1 - e^(-LOCKED_DV/gisp).
    LOCK LOCKED_DT to LOCKED_XF * mgispm.

    local wt is n:eta - LOCKED_DT/2.
    local t0 is time:seconds + LOCKED_DT.
    print "mx:"
      +" dv="+round(v0:mag,1)
      +" dt="+round(LOCKED_DT,1)
      +" wt="+round(wt,1).

    set b0 to n:burnvector. set LOCKED_BT to 0.
    LOCK throttle to LOCKED_BT. LOCK steering to b0.

    set warp to 0.
    if t0 > 30 { wait 10. warpto(t0 - 10). }
    wait until time:seconds >= t0.
    set b1 to n:burnvector.
    LOCK steering to b1.
    LOCK LOCKED_BT to sqrt(max(0,min(1,LOCKED_DT))).
    wait until vdot(n:burnvector, b0) < 0.
    set LOCKED_BT to 0.
    print "mx: residual dV: "+round(n:burnvector:mag,3)+" m/s".
    wait 3.
    unlock steering.
    unlock throttle.

    remove n.
  }

  // mt: calculation of maneuver time
  // from CheersKevin's KSProgramming series
  // episode 45 has what I think is the final version.
  // i have tweaked it:
  // - external isp() function weights isp by thrust.
  // - avoid divde by zero when maxthrust is zero.
  // it was then inlined above and tricks were pulled.
  function mt { parameter dV.
    local th is maxthrust.
    if th <= 0 return 0.

    local m is ship:mass.

    local mu is ship:orbit:body:mu.
    local r0 is ship:obt:body:radius.
    local g is mu/r0^2.

    local gisp is g * isp().
    local mgispm is m * gisp / th.

    local xf is 1 - e^(-dV/gisp).
    local dt is xf * mgispm.

    return dt.
  }

  // isp(): compute effective ISP of current stage.
  // weights ISP of engines by their available thrust.
  function isp {
    local weighted_sum is 0.
    list engines in all_engines.
    for en in all_engines {
      if en:ignition and not en:flameout {
        set weighted_sum to weighted_sum + en:isp * en:availablethrust.
      }
    }
    return weighted_sum / maxthrust.
  }

}
