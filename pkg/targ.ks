@LAZYGLOBAL off.
{   parameter targ is lex().    // target management package.

    local nv is import("nv").
    local io is import("io").

    targ:add("save", {          // nv:put info about target.
        local o is target:orbit.
        // io:say("locking target: "+target:name).
        nv:put("targ/name", target:name).
        nv:put("targ/apo", o:apoapsis).
        nv:put("targ/peri", o:periapsis).
        nv:put("targ/inc", o:inclination).
        nv:put("targ/ecc", o:eccentricity).
        nv:put("targ/sma", o:semimajoraxis).
        nv:put("targ/lan", o:lan).
        nv:put("targ/aop", o:argumentofperiapsis).
        nv:put("targ/mae", o:meananomalyatepoch).
        nv:put("targ/epoch", o:epoch).
        return 0. }).

    targ:add("clear", {
        nv:clr("targ/name").
        nv:clr("targ/apo").
        nv:clr("targ/peri").
        nv:clr("targ/inc").
        nv:clr("targ/ecc").
        nv:clr("targ/sma").
        nv:clr("targ/lan").
        nv:clr("targ/aop").
        nv:clr("targ/mae").
        nv:clr("targ/epoch").
        return 0. }).

    targ:add("valid", {
        if not nv:has("targ/name") return false.
        local tn is list().
        local tl is list().
        local bl is list().
        list targets in tl. for t in tl tn:add(t:name).
        list bodies in bl. for b in bl tn:add(b:name).
        local t is nv:get("targ/name").
        if not tn:contains(t) return false.
        set target to t. wait 0.
        targ:save().
        return true.
    }).

    targ:add("orbit", {         // create an orbit from the nv "targ/*" data.
        return createorbit(
            nv:get("targ/inc", 0),
            nv:get("targ/ecc", 0),
            nv:get("targ/sma", 0),
            nv:get("targ/lan", 0),
            nv:get("targ/aop", 0),
            nv:get("targ/mae", 0),
            nv:get("targ/epoch", 0),
            body). }).

    // local sma is body:radius + (apo + peri)/2.
    // local ecc is abs(apo - peri) / (2*sma).

    targ:add("load", {
        if hastarget { return targ:save(). }
        if targ:valid() { return 0. }
    }).

    targ:add("wait", {
        if hastarget { return targ:save(). }
        if targ:valid() { return 0. }
        io:say("Please select target", false).
        return 5. }).
}
