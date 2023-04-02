@LAZYGLOBAL off.
{   parameter go. // GO script for "T/05" Mun Orbital Tourism.

    local io is import("io").
    local nv is import("nv").
    local seq is import("seq").
    local sch is import("sch").
    local predict is import("predict").
    local visviva is import("visviva").
    local phase is import("phase").
    local scan is import("scan").
    local targ is import("targ").
    local match is import("match").
    local plan is import("plan").
    local hill is import("hill").
    local rdv is import("rdv").
    local dbg is import("dbg").
    local ctrl is import("ctrl").

    local orbit_altitude is nv:get("launch_altitude", 80000, true).
    local launch_azimuth is nv:get("launch_azimuth", 90, true).
    local launch_pitchover is nv:get("launch_pitchover", 3, false).

    local target_name is "Mun".
    local target_alt is 50000.
    set TARGET to target_name.

    local wait_until_in_soi_of is { parameter name.
        if body:name = name {
            io:say("Arrived in "+name+" SOI.").
            kuniverse:timewarp:cancelwarp().
            ctrl:dv(V(0,0,0),1,1,5).
            return -15. }
        if not kuniverse:timewarp:issettled return 1/10.
        if kuniverse:timewarp:rate>1 return 5.
        ctrl:dv(V(0,0,0), 0, 0, 0).
        // dbg:pv("wait_until_in_soi_of "+name+" eta ", TimeSpan(eta:transition)).
        if eta:transition > 60 warpto(time:seconds + eta:transition - 30).
        if eta:transition > 10 return 5.
        return clamp(5, 15, eta:transition). }.

    local function establish_descent {

        // io:say("establish_descent: "+target_name).
        until not hasnode { remove nextnode. wait 0. }

        if body:name<>target_name {
            io:say("  oops, body name is "+body:name).
            return 5. }

        local r0 is body:radius.

        local t1 is eta:periapsis + time:seconds.
        local p1 is predict:pos(t1, ship).
        local v1 is predict:vel(t1, ship).
        local r1 is p1:mag.
        local s2 is visviva:v(r1, r0+target_alt, r1).
        local v2 is v1:normalized * s2.
        local dv is v2 - v1.

        plan:dvt(dv, t1).
        return 0. }

    local function fine_tune_descent {

        // io:say("fine_tune_descent: "+target_alt).

        local good_enough is 100.

        local dv is {
            local r0 is body:radius.
            local rc is body:position:mag.
            local vc is velocity:orbit.
            local sd is visviva:v(rc, r0+periapsis, r0+apoapsis).
            local vd is vc:normalized*sd.
            return vd - vc. }.

        local err is target_alt-periapsis.

        if abs(err) <= good_enough or dv():mag<0.001 {
            lock throttle to 0.
            lock steering to retrograde.
            return 0. }

        ctrl:dv(dv).
        return 5. }

    local axes is list(
        V(1,0,0), V(-1,0,0),
        V(0,1,0), V(0,-1,0),
        V(0,0,1), V(0,0,-1)).

    local function establish_mun_to_kerbin {

        until not hasnode { remove nextnode. wait 0. }.
        local n is node(time:seconds+300, 0, 0, 0). add n. wait 0.

        local return_pe is 20000 + body:orbit:body:atm:height.

        local function find_desired_transit {

            local Tmin is time:seconds + orbit:period.
            local Tmax is Tmin + body:orbit:period.

            local function fitness {   parameter t.                // fitness function to maximize
                if t<tMin return "skip".
                if t>tMax return "halt".
                local VshipAtT is predict:vel(t, ship). // ship around body
                local VbodyAtT is predict:vel(t, body). // body around ITS PARENT
                return vang(VshipAtT,VbodyAtT). }

            local start is Tmin.
            local dtMax is orbit:period/8.
            local dtMin is 1.
            local scorethresh is 1.

            local prev_improved is false.
            local prev_angle is 2^64.
            local prev_time is start.

            until start > Tmax {
                local dt is dtMax.

                local function fitincr {   parameter t.                // apply state increment
                    return t + dt. }

                local function fitfine {   parameter t, ds.            // reduce state increment
                    if dt <= dtMin return true.
                    if ds <= scorethresh return true.
                    set dt to max(dtMin, dt/3).
                    return false. }

                local scanner is scan:init(fitness@, fitincr@, fitfine@, start).
                until scanner:step() {}
                if scanner:failed break.

                local t is scanner:result.
                local VshipAtT is predict:vel(t, ship).         // ship around body
                local VbodyAtT is predict:vel(t, body).         // body around ITS PARENT
                local AngleAtT is vang(VshipAtT, vBodyAtT).

                if prev_improved and AngleAtT < prev_angle
                    break.

                set prev_improved to AngleAtT > prev_angle.
                set prev_angle to AngleAtT.
                set prev_time to t.

                set start to t + orbit:period/4. }

            return prev_time. }

        local function fitness_of_t_p { parameter t, p.
            set nextnode:time to t.
            set nextnode:prograde to p.
            wait 0.
            local o1 is n:orbit.
            if not o1:hasnextpatch      // does not leave local soi.
                return -2^64.           // infinitely bad.
            local o2 is o1:nextpatch.
            if o2:hasnextpatch          // leaves parent soi before periapsis
                if o2:nextpatcheta < o2:eta:periapsis
                    return -2^64.       // infinitely bad.
            local pe is o2:periapsis.
            local score is 0
                -abs(pe - return_pe)/1000       // reduce score by PE error
                -n:deltav:mag.                  // reduce score by DV magnitude
            return score. }

        local score_t is lex().
        local prog_t is lex().
        local function burn_time_fitness_fn { parameter data_t.
            local t is data_t[0].
            if score_t:haskey(t) return score_t[t].

            local score_p is lex().
            local data_p is hill:seeks(list(400), { parameter data_p.
                    local p is data_p[0].
                    if score_p:haskey(p) return score_p[p].
                    local score is fitness_of_t_p(t, p).
                    set score_p[p] to score.
                    return score. },
                list(10, 3, 1, 0.3, 0.1)).

            set p to data_p[0].
            local score is fitness_of_t_p(t, p).

            set prog_t[t] to p.
            set score_t[t] to score.
            return score. }

        local polar_transit_t is find_desired_transit().

        local p is orbit:period.

        hill:seeks( // hillclimb to the best departure time.
            list(polar_transit_t), //  - p/8),
            burn_time_fitness_fn@,
            list(p/10, p/30, p/100, p/300, p/1000, p/3000)).

        return 0. }

    seq:do(list(
        "PADHOLD", targ:wait, match:asc,
        "COUNTDOWN", phase:countdown,
        "Launch", phase:launch,
        "Ascent", phase:ascent,
        "Coast", phase:coast,
                {   // switch to the map view.
                    // too bad we can't set the FOCUS from here.
                    set mapview to true. return 0. },
        "Circularize", plan:circ_ap, plan:go, phase:circ,
                {   // turn on lights which also extends the radio dishes.
                    lights on. return 0. },
        "Match Inclination", plan:match_incl,
        "Mun Xfer Inject", plan:xfer, plan:go,

        // Drop the long "mun injection" stage so we can maneuver.
        "Lighten(3)", phase:lighten:bind(3),

        "Mun Xfer Correct", plan:corr, plan:go,

        "Coast to Mun", wait_until_in_soi_of:bind(target_name),

        "Mun Transition", establish_descent@, plan:go, fine_tune_descent@,
        "Mun Orbit", plan:circ_pe, plan:go, phase:circ,

                {   // switch back to the local view of the vessel.
                    set mapview to false. return 0. },

                {   // wait until the flight engineer turns off the lights.
                    if not lights { lights on. return 0. }
                    io:say("ENJOY THE VIEW.", false).
                    io:say("turn off lights to return.", false).
                    return 5. },

                {   // switch back to the map view.
                    set mapview to true. return 0. },

        "Mun Departure", establish_mun_to_kerbin@, plan:go,

        "Coast past Mun", wait_until_in_soi_of:bind("Kerbin"),

                {   // tap the brakes to retract the antenna.
                    if (brakes) { brakes off. return 0. }
                    print "retract antenna at altitude " + altitude.
                    brakes on. return 1. },

        "AERO", phase:aero, // when phase:aero ends, periapsis is in the lower half of the atmosphere.
        "DECEL", phase:decel,
                {   // switch back to the local view of the vessel.
                    set mapview to false. return 0. },
        "LIGHTEN", phase:lighten,
        "PSAFE", phase:psafe,
        "CHUTE", phase:chute,
        "LAND", phase:land,
        "PARK", phase:park)).

    go:add("go", {
        sch:schedule(time:seconds, phase:autostager).
        sch:schedule(time:seconds, phase:autorcs).
        seq:go(). }). }