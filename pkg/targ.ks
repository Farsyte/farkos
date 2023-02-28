@LAZYGLOBAL off.
{   parameter targ is lex().    // target management package.

    local nv is import("nv").
    local io is import("io").

    targ:add("target", false).          // mission target Orbitable (or "" if not Body or Vessel)
    targ:add("orbit", false).           // mission target Orbit (or "" during initial import)
    targ:add("load", {                          // set TARGET to mission target (or nothing)
        if targ:target:istype("Orbitable")
            set target to targ:target.
        else
            set target to "".
        return 0. }).

    targ:add("save", {                          // set mission target to TARGET (or optional argument)
        parameter sel is choose target if hastarget else "".

        if sel:istype("String") {               // can specify target by name.
            if body_names:contains(sel)         // OK to specify a BODY name.
                set sel to body(sel).
            else if vessel_names:contains(sel)  // OK to specify a VESSEL name.
                set sel to vessel(sel).
            else                                // MAY add standard orbits later (LKO, HKO, KSO, etc)
                return targ:clr(). }            // if not a supported name, CLEAR THE MISSION TARGET.

        // String values passed have now been converted to Orbitable objects.

        if sel:istype("Orbitable") {            // can specify with an Orbitable object.
            set target to sel.
            write_orbitable(sel).               // persist the name so we can restore after reboot.
            set targ:target to sel.             // update KSP TARGET
            set sel to sel:orbit. }             // get its associated Orbit.

        else {
            set targ:target to "". }            // if not an orbitable, clear TARGET.

        // String and Orbitable passed have now been converted to Orbit.

        if sel:istype("Orbit") {                // can specify with an Orbit object.
            set targ:orbit to sel.              // make available to callers.
            write_orbit(sel). }

        else {
            return targ:clr(). }                // if we do not have an Orbit, clear the mission target.

        return 0. }).

    targ:add("clear", {                         // clear mission target.
        write_orbitable(false).
        set targ:target to "".
        set targ:orbit to "".
        return 0. }).


    targ:add("wait", {                          // wait for TARGET, then make it the mission target.
        if hastarget { return targ:save(). }
        // periodically show a hud message.
        io:say("Please select target", false).
        return 5. }).

    targ:add("restore", {                       // load mission target from persisted data.

        // if TARGET is set, select it as our mission target.

        if hastarget return targ:save(target).

        // if targ/name is persisted, set it as our mission target.
        // clear targ/name if it is a name of a thing that does not exist.

        if nv:has("targ/name") {
            local n is nv:get("targ/name").
            if targ_names:contains(n)
                return targ:save(n).
            nv:clr("targ/name"). }

        // Construct a target orbit using the persisted euler parameters,
        // using the ship's orbit to build a default when some or all
        // of the parameters are not set.

        local o is ship:orbit.

        local b is body(nv:get("targ/body", o:body:name)).

        // The default target orbit will basically match the current orbit,
        // raised to be above the atmosphere.

        local min_sma is b:radius + b:atm:height.
        local curr_sma is o:semimajoraxis.
        local def_sma is choose min_sma + 10000 if curr_sma<min_sma else curr_sma.

        local inc is nv:get("targ/euler/inc", o:inclination).
        local ecc is nv:get("targ/euler/ecc", 0).
        local sma is nv:get("targ/euler/sma", max(o:semimajoraxis, def_sma)).
        local lan is nv:get("targ/euler/lan", o:lan).
        local aop is nv:get("targ/euler/aop", o:argumentofperiapsis).
        local mae is nv:get("targ/euler/mae", o:meananomalyatepoch).
        local epoch is nv:get("targ/euler/epoch", o:epoch).

        local o is createorbit(inc, ecc, sma, lan, aop, mae, epoch, b).

        return targ:save(o). }).

    targ:add("resize", {                        // change periapsis and apoapsis of orbit.
        parameter r1 is targ:orbit:sma.         // distances are RADIUS not ALTITUDE.
        parameter r2 is r1.                     // default to circular

        local sma is (r1+r2) / 2.
        local ecc is abs(r1-r2)/(r1+r2).

        nv:clr("targ/name").
        nv:put("targ/euler/ecc", ecc).
        nv:put("targ/euler/sma", sma).
        return targ:load(). }).

    targ:add("incline", {                       // change orbital plane
        parameter inc.                          // inclination is in degrees
        parameter aop is                        // default to no AOP change
            targ:orbit:argumentofperiapsis.
        nv:clr("targ/name").
        nv:put("targ/euler/inc", inc).
        nv:put("targ/euler/aop", aop).
        return targ:load(). }).


    local function get_vessel_names {           // build a UniqueSet of vessel names.
        local result is uniqueset().
        local vessel_list is list().
        local each_vessel is "".
        list targets in vessel_list.
        for each_vessel in vessel_list
            result:add(each_vessel:name).
        return result. }

    local function get_body_names {             // build a UniqueSet of body names.
        local result is uniqueset().
        local body_list is list().
        local each_body is "".
        list bodies in body_list.
        for each_body in body_list
            result:add(each_body:name).
        return result. }

    local vessel_names is get_vessel_names().
    local body_names is get_body_names().

    local function write_orbitable {            // persist current mission target orbitable
        parameter sel is targ:target.

        if sel:istype("Orbitable") {
            nv:put("targ/name", sel:name).
            write_orbit(sel:orbit). }

        else {
            nv:clr("targ/name", sel:name).
            write_orbit(sel). } }

    local function write_orbit {                // persist current mission target orbit
        parameter sel is targ:orbit.

        if sel:istype("Orbit") {
            nv:put("targ/euler/inc", sel:inclination).
            nv:put("targ/euler/ecc", sel:eccentricity).
            nv:put("targ/euler/sma", sel:semimajoraxis).
            nv:put("targ/euler/lan", sel:lan).
            nv:put("targ/euler/aop", sel:argumentofperiapsis).
            nv:put("targ/euler/mae", sel:meananomalyatepoch).
            nv:put("targ/euler/epoch", sel:epoch).
            nv:put("targ/body", sel:body:name). }

        else {
            nv:clr("targ"). } }

    local function initialize_mission_target {              // initialize the mission target (use TARGET, or persisted)
        if hastarget {
            targ:save(target). }
        else {
            targ:restore(). } }

    initialize_mission_target(). }
