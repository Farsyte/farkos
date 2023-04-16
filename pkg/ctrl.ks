@LAZYGLOBAL off.
{   parameter ctrl is lex().    // augmented control package

    local phase is import("phase").
    local io is import("io").

    // allow missions to tweak these parameters.
    ctrl:add("gain", 1).    // gain: acceleration per change in velocity
    ctrl:add("emin", 1).    // if facing within this angle, use computed throttle
    ctrl:add("emax", 15).   // if facing outside this angle, use zero throttle

    ctrl:add("pose", {                          // establish an idle pose
        // ctrl:pose() constructs a Direction suitable for steering, which
        // is a reaonable "idle pose" for the current mission state.
        // - if Above the atmosphere: point normal to the orbit.
        // - else if Rising through atmosphere: surface prograde.
        // - else if Descending through atmosphere: surface retrograde
        // - else if moving fast through the atmosphere: surface prograde
        // - else point away from the body, minimizing roll
        // Except for the last, use "pilot feet toward body we are orbiting"
        if altitude>body:atm:height
            return lookdirup(vcrs(ship:velocity:orbit, -body:position), -body:position).
        if verticalspeed>10
            return lookdirup(srfprograde:vector, facing:topvector).
        if verticalspeed<10
            return lookdirup(srfretrograde:vector, facing:topvector).
        if airspeed>100
            return lookdirup(srfprograde:vector, facing:topvector).
        return lookdirup(up:vector, facing:topvector). }).

    ctrl:add("steering", {                      // steer based on delta-v
        parameter dv_fd.                   // lambda that returns delta-v
        // ctrl:steering(dv_fd) constructs a direction vector appropraite
        // to the Delta-V value passed in, which may be a Function Delegate.
        // If the Delta-V vector is zero, the returned direction is from ctrl:pose().
        local dv is eval(dv_fd).
        if dv:mag>0 return lookdirup(dv, facing:topvector).
        return ctrl:pose(). }).

    ctrl:add("throttle", {                      // thrust based on delta-v.
        parameter dv_fd.                   // lambda that returns delta-v
        parameter raw is false.         // add ", true" to see un-discounted value
        // ctrl:throttle(dv_fd) computes an appropriate throttle setting
        // for the given desired Delta-V vector. This takes into account
        // the current available thrust, how much acceleration we can get
        // from that thrust, and the angle between where we are facing and
        // the direction of the burn.
        // If the Delta-V vector is tiny, we return zero, giving a very very
        // small "dead zone" for the throttle. This is intended to allow a
        // control facility to indicate a pointing direction, without also
        // having any thrust generated.
        // If the optional second parameter is set to TRUE, then this function
        // returns the raw throtle value before discounting based on the
        // error in orientation, which is useful for deciding to terminate
        // a maneuver when the required throttle is below a threshold.

        if availablethrust=0 return 0.

        local dv is eval(dv_fd).
        if dv:mag<2/10000 return 0.     // tiny deadzone for tiny thrust -> engines off.

        local dt is ctrl:gain*dv:mag*ship:mass/availablethrust.
        local desired_throttle is clamp(0,1,dt/2).
        if raw return desired_throttle.

        local facing_error is vang(facing:vector,dv).
        if facing_error<=ctrl:emin return desired_throttle.
        if facing_error>=ctrl:emax return 0.

        local df is (facing_error-ctrl:emin) / (ctrl:emax-ctrl:emin).
        return round(df*desired_throttle,4). }).

    ctrl:add("dv", { parameter dv_fd.           // dv based throttle & steering
        parameter gain is ctrl:gain.
        parameter emin is ctrl:emin.
        parameter emax is ctrl:emax.
        // Lock steering and throttle so they start tracking appropriate
        // direction and thrust based on a Delta-V value returned from the
        // given function delegate. Optional paremeters allow tuning of the
        // various control parameters. Steering and Throttle will track
        // the appropriate values until some other facility overrides the
        // setting of the k-OS THROTTLE and STEERING controls.
        set ctrl:gain to gain.
        set ctrl:emin to emin.
        set ctrl:emax to emax.
        sas off.
        lock steering to ctrl:steering(dv_fd).
        lock throttle to ctrl:throttle(dv_fd).
        wait 0. }).

    ctrl:add("rcs_off", {                       // cancel CTRL-mediated RCS translation.
        // Terminate the use of RCS controls set up by other CTRL facilities.
        // This neutralizes the RCS based translation controls in k-OS, turns
        // off the special override that keeps RCS enabled, and restroes k-OS
        // cooked controls to maintain zero thrust in a parked pose.
        io:say("CTRL: terminating RCS translation.").
        set ship:control:neutralize to true.
        set phase:force_rcs_on to 0.
        sas off. rcs off.
        ctrl:dv(V(0,0,0),1,1,5).
        return 0. }).

    ctrl:add("rcs_dv_gain", 1/2).
    ctrl:add("rcs_dv", { parameter dv_fd.       // DV based RCS control
        // Use the RCS jets to apply a required Delta-V to the vessel.
        // This is intended to be used when the Delta-V is small, and
        // we want to avoid changing the attitude of the vessel.
        local rcs_list is list().
        local it is 0.
        local sum to 0.
        list rcs in rcs_list. for it in rcs_list
            set sum to sum + it:availablethrust.
        if sum<1/100 {
            // Sanity check. If we have no RCS fuel remaining,
            // terminate RCS based control, emit a message,
            // and return to the idle pose.
            set phase:force_rcs_on to 0.
            rcs off.
            io:say("CTRL: RCS has no fuel.").
            return ctrl:dv(V(0,0,0),1,1,5). }

        // presume half our RCS units are effective in each direction.
        local rcs_translation_gain is 2/sum.

        local _steering is {
            // This function delegate will be called frequently by the
            // cooked steering mechanism. It's job is to compute the remaining
            // Delta-V to be applied, and adjust the RCS translation controls as
            // appropriate, while instructing the Cooked STEERING facility to
            // minimize any change in vessel orientation.
            //
            // Note that if our orientation is changed, this code will attempt
            // to hold the new orientation rather than fighting with the RCS to
            // return to the original orientation.

            local desried_deltav is eval(dv_fd).
            local desired_accel is desried_deltav * ctrl:rcs_dv_gain.
            local desired_force is ship:mass * desired_accel.
            local desired_trans is desired_force * rcs_translation_gain.
            local desired_trans_suf is facing:inverse * desired_trans.
            local desired_trans_suf_dir is desired_trans_suf:normalized.
            local trmag is desired_trans_suf:mag.

            // RCS has a KSP-enforced 5% deadzone.
            // if we want nonzero RCS below this limit,
            // but not below 0.1%, then fire at 5% and hope
            // that we can cut off the jets before overshooting,
            // but in practice we will either settle close to the
            // desired velocity, or wobble back and forth around
            // it, until someone cancels the control.

            if trmag<1/1000 {

                // if we want essentially zero RCS, neutralize controls.
                set ship:control:neutralize to true. }

            else if trmag<1/20 {

                // if we want <10% RCS, ask for 10%
                // as the 5% deadzone may be applied
                // independently for each thruster.
                set ship:control:translation to desired_trans_suf_dir/20.}

            else if trmag>1 {

                // limit to 100% in our net direction, lest we end up
                // saturating on some axes and not on others.
                set ship:control:translation to desired_trans_suf_dir.}

            else {

                // magnitude in the linear region 10% to 100%.
                set ship:control:translation to desired_trans_suf. }

            // while we are mucking about with the thrusters,
            // please maintain our original orientation.

            return facing. }.

        unlock throttle.
        unlock steering.
        set phase:force_rcs_on to 1.
        sas off. rcs on.
        lock steering to _steering().

        return 0. }).

    ctrl:add("rcs_dx_speed_limit", 2).
    ctrl:add("rcs_dx", { parameter dx_df.       // DX based RCS control
        // Use the RCS jets to drive our position error to zero.
        // The position error is obtained by evaluating the provided
        // function deleagate.
        return ctrl:rcs_dv({
            if not hastarget return V(0,0,0).
            local dx is eval(dx_df).
            local cv_lin is dx/5.

            // cap commanded relative velocity to 1 m/s
            if cv_lin:mag > ctrl:rcs_dx_speed_limit
                set cv_lin to cv_lin:normalized*ctrl:rcs_dx_speed_limit.

            local sv is ship:velocity:orbit.
            local tv is target:velocity:orbit.
            local rv is sv - tv.

            return cv_lin - rv. }). }).

}
