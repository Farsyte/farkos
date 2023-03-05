@LAZYGLOBAL off.
{   parameter targ is lex().    // target management package.

    local nv is import("nv").
    local io is import("io").
    local dbg is import("dbg").
    local memo is import("memo").
    local predict is import("predict").

    // TODO verify support for DockingPort as TARGET.

    targ:add("parking_distance", 5).

    targ:add("targ_from_ship", {
        if hastarget return target:position.
        if targ:target:hassuffix("position") return targ:target:position.
        if targ:orbit:hassuffix("position") return targ:orbit:position.
        return V(0,0,0). }).

    targ:add("facing", {
        if hastarget return target:facing.
        if targ:target:hassuffix("facing") return targ:target:facing.
        // final fallback is to use ship facing if we do not have a target facing.
        return ship:facing. }).

    targ:add("park_from_ship", {
        parameter d is targ:parking_distance.
        local p is targ:targ_from_ship().
        return p - p:normalized*targ:parking_distance. }).

    local draw_parking_vecdraws is list().

    targ:add("draw_parking", {
        local d is targ:parking_distance.
        local axes is list (
            V(1,0,0),V(-1,0,0),
            V(0,1,0),V(0,-1,0),
            V(0,0,1),V(0,0,-1)).
        local axis is V(0,0,0).
        draw_parking_vecdraws:clear().

        draw_parking_vecdraws:add(      // represent parking position as vector in ship facing Y direction.
            vecdraw(targ:park_from_ship, { return facing*V(0,1,0)*5. }, RGB(0,1,1),
                "", 1.0, true, 0.2, true, true)).

        // draw a vector from the target along its +Z axis.
        draw_parking_vecdraws:add(      // represent target as vector in target facing Z direction.
            vecdraw(targ:targ_from_ship, {
                return targ:facing()*V(0,0,1)*5. }, RGB(0,1,1),
                "", 1.0, true, 0.2, true, true)).

        } ).

    // targ:standoff(t) returns the predicted standoff target
    // at some specific universal time t, for use by long range
    // planning.
    targ:add("standoff", {
        parameter t is time:seconds.
        local t_p is predict:pos(t, target).
        return t_p - t_p:normalized*targ:standoff_distance. }).

    targ:add("name", "").                       // mission target String  (or "" if not set)
    targ:add("target", "").                     // mission target (for KSP TARGET) (or "" if not set)
    targ:add("orbit", "").                      // mission target Orbit (or "" if not set)

    targ:add("standoff_distance", 100).          // default standoff distance (toward the body)

    local function nameof { parameter x.
        return choose x:name if x:hassuffix("name") else x:tostring. }

    targ:add("load", {                          // set TARGET to mission target (or nothing)

        local ctn is choose target:name if hastarget else "".
        local mtn is choose "" if targ:target="" else targ:target:name.
        if ctn<>mtn set target to targ:target. return 0. }).

    targ:add("save", {                          // set mission target to TARGET (or optional argument)
        parameter sel is choose target if hastarget else "".

        if sel:istype("String") {               // can specify target by name.
            if sel="" {                         // explicit "clear target" request
                return targ:clr(). }
            local obj is named(sel).              // convert to something we can target
            if obj="" {
                print "targ:save rejecting '"+sel+"'".
                return 0. }
            set sel to obj. }

        if sel:hassuffix("name") {              // update targ:name before moving from sel to its parent.
            set targ:name to sel:name. }
        else {
            set targ:name to "". }

        if sel:istype("DockingPort") {          // a DockingPort has been selected.
            set targ:port to target.            // remember the selected port
            set sel to sel:ship. }              // get the associated Orbitable.
        else {
            set targ:port to "". }              // remember selected is not a port.

        if sel:istype("Orbitable") {            // can specify with an Orbitable object.
            set targ:orbitable to sel.             // remember the selected orbitable
            set sel to sel:orbit. }             // get its associated Orbit.
        else {
            set targ:orbitable to "". }            // remember selected is not an orbitable.

        if sel:istype("Orbit") {                // can specify with an Orbit object.
            set targ:orbit to sel.              // remember the selected orbit.
            nv_put_orbit(sel). }                 // persist the orbital parameters.
        else {
            set targ:orbit to "". }              // if we do not have an Orbit, clear the mission target.

        nv_put_name().
        nv_put_orbit().

        return 0. }).

    targ:add("clear", {                         // clear mission target.
        nv:clr("targ").
        set targ:name to "".
        set targ:port to "".
        set targ:orbitable to "".
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
            local n is nv:get("targ/name", "").
            set n to named(n).
            if n<>"" return targ:save(n).
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

    local map is create_map().

    local function create_map {
        local m is lex(), l is list(), e is "".
        list targets in l. for e in l set m[e:name] to e.
        list bodies in l. for e in l set m[e:name] to e.
        list parts in l. for e in l if e:istype("DockingPort") set m[e:name] to e.
        return m. }

    local function named { parameter n.
        return choose map[n] if map:haskey(n) else "". }

    local function nv_put_name {            // persist current mission target orbitable
        parameter name is targ:name.
        if name:hassuffix("name") set name to name:name.
        nv:put("targ/name", name). }

    local function nv_put_orbit {                // persist current mission target orbit
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

    targ:restore(). }
