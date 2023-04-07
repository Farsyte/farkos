@LAZYGLOBAL off.
{   parameter ctrl is lex().    // augmented control package

    local phase is import("phase").
    local io is import("io").

    // allow missions to tweak these parameters.
    ctrl:add("gain", 1).    // gain: acceleration per change in velocity
    ctrl:add("emin", 1).    // if facing within this angle, use computed throttle
    ctrl:add("emax", 15).   // if facing outside this angle, use zero throttle

    ctrl:add("pose", {                          // establish an idle pose
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
        local dv is eval(dv_fd).
        if dv:mag>0 return lookdirup(dv, facing:topvector).
        return ctrl:pose(). }).

    ctrl:add("throttle", {                      // thrust based on delta-v.
        parameter dv_fd.                   // lambda that returns delta-v
        parameter raw is false.         // add ", true" to see un-discounted value

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
        set ctrl:gain to gain.
        set ctrl:emin to emin.
        set ctrl:emax to emax.
        sas off.
        lock steering to ctrl:steering(dv_fd).
        lock throttle to ctrl:throttle(dv_fd).
        wait 0. }).

    ctrl:add("rcs_off", {                       // cancel CTRL-mediated RCS translation.
        io:say("CTRL: terminating RCS translation.").
        set ship:control:neutralize to true.
        set phase:force_rcs_on to 0.
        sas off. rcs off.
        ctrl:dv(V(0,0,0),1,1,5).
        return 0. }).

    ctrl:add("rcs_dv_gain", 1/2).
    ctrl:add("rcs_dv", { parameter dv_fd.       // DV based RCS control

        local rcs_list is list().
        local it is 0.
        local sum to 0.
        list rcs in rcs_list. for it in rcs_list
            set sum to sum + it:availablethrust.
        if sum<1/100 {
            set phase:force_rcs_on to 0.
            rcs off.
            io:say("CTRL: RCS has no fuel.").
            return ctrl:dv(V(0,0,0),1,1,5). }

        // presume half our RCS units are effective in each direction.
        local rcs_translation_gain is 2/sum.

        local _steering is {
            local desried_deltav is eval(dv_fd).
            local desired_accel is desried_deltav * ctrl:rcs_dv_gain.
            local desired_force is ship:mass * desired_accel.
            local desired_trans is desired_force * rcs_translation_gain.
            local desired_trans_suf is facing:inverse * desired_trans.
            local desired_trans_suf_dir is desired_trans_suf:normalized.
            local trmag is desired_trans_suf:mag.

            // RCS has a KSP-enforced 5% deadzone.
            // if we want nonzero RCS below this limit,
            // fire at 10% and try to be brief.

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
