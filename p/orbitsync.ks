{
    export(orbitsync@).

    function orbitsync {
        parameter Hq.                // altitude of apoapsis
        parameter Hp.                // altitude of periapsis

        global Cs is facing.
        global Ct is 0.

        local R0 is body:radius.
        local MU is body:mu.

        // vis-viva: v^2/mu = 2/r - 1/a
        //   v is vessel velocity
        //   mu is gravitational parameter, GM/r^2
        //   r is current radius
        //   a is semi-major axis
        // If you know any three, you can solve for the other.

        // kepler's 2nd law: an orbiting object sweeps out equal areas
        // in equal times: radius times lateral speed is constant.


        // controller gain. note that mass and maxthrust are
        // accounted for separately.
        local Kt is 1/5.

        local Rq is R0+Hq.                           // radius at apoapsis
        local Rp is R0+Hp.                           // radius at periapsis
        local A is (Rp+Rq)/2.                        // semi-major axis
        local Sq is sqrt(MU*(2/Rq-1/A)).             // [vis-viva] speed at apoapsis
        local ASR is Sq*Rq.                          // [kepler-2] area sweep rate, m^2/sec

        // everything above remains constant based on the requested orbit,
        // everything below will change over time. using LOCK will assure
        // that we smoothly follow the proper burn vector, even if this
        // method is not frequently called.

        lock h to altitude.
        lock vo to velocity:orbit.
        lock vu_hat to up:vector.

        lock r to R0 + h.                            // current radius.
        lock s to sqrt(MU*(2/r - 1/A)).              // [kepler-2] target speed
        lock sh to ASR/r.                            // target horizontal speed
        lock su to sqrt(max(0,s^2 - sh^2)).          // [pythagoras] target vertical speed
        // TODO: smartly select sign of su to minimize burn.
        lock vh_hat to vxcl(vu_hat,vo):normalized.   // horizontal velocity direction
        lock v to vh_hat*sh + vu_hat*su.             // total target velocity
        lock dv to v - vo.                           // velocity error
        lock ds to dv:mag.                           // size of correction
        lock ao to vang(facing:vector,dv).           // angle offset (facing vs burn)
        lock af to 1 - ao/20.                        // thrust discount due to angle error
        lock ma to max(1,maxthrust)/mass.            // acceleration at max throttle

        lock Cs to lookdirup(dv,facing:topvector).   // steer, minimizing roll
        lock Ct to min(1,max(0,af*Kt*ds/ma)).        // desired throttle

        lock throttle to Ct.
        lock steering to Cs.

        return ds.
    }
}
