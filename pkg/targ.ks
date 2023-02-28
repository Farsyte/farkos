@LAZYGLOBAL off.
{   parameter targ is lex().    // target management package.

    local nv is import("nv").
    local io is import("io").

    local vessel_names is uniqueset().
    local body_names is uniqueset().

    // current usage of targ package:
    //
    //      targ:save()     called as mission phase step
    //                      set mission target to TARGET
    //                      if TARGET unset, then unset mission target
    //
    //      targ:wait()     if TARGET set, [re]commit item as mission target
    //                      else if mission target committed, use item
    //                      else return 5 until a condition above is met
    //
    //      targ:load()     if TARGET set, [re]commit item as mission target
    //                      else if mission target commited, use item
    //                      behavior TBD if above conditions not met
    //                      like wait but weaker?
    //
    //      targ:orbit()    return the mission target Orbit object
    //
    // desired update
    // - targ:orbit         return the mission target Orbit object
    // - targ:wait()        stall until TARGET set; commit TARGET as mission target
    // - targ:save(o)       set the mission target to optional o
    // - targ:load()        set TARGET to mission target (or unset if not set to an orbitable)
    // targ:save() will clear the mission target if TARGET is not set.
    //
    // available built-in orbit constructors:
    // - createorbit(inc, ecc, sma, lan, aop, mae, epoch, body)
    // - createorbit(pos, vel, body, ut)
    //
    // during boot, set the current mission target:
    // - if HASTARGET, select TARGET. else,
    // - if targ/name persisted, select item if possible (if not, clear targ/name)
    // - use persisted orbital elements with reasonable defaults to build an orbit

    targ:add("load", {
        if targ:target:istype("Orbitable")
            set target to targ:target.
        else
            set target to "".
        return 0. }).

    targ:add("save", {          // nv:put info about target.
        parameter sel is choose target if hastarget else "".

        if sel:istype("String") {
            if body_names:contains(sel)
                set sel to body(sel).
            else if vessel_names:contains(sel)
                set sel to vessel(sel).
            else
                return targ:clr(). }

        if sel:istype("Orbitable") {
            set target to sel.
            nv:put("targ/name", sel:name).
            set targ:target to sel.
            set sel to sel:orbit. }
        else {
            set targ:target to "". }

        if sel:istype("Orbit") {
            set targ:orbit to sel.
            nv:put("targ/euler/inc", sel:inclination).
            nv:put("targ/euler/ecc", sel:eccentricity).
            nv:put("targ/euler/sma", sel:semimajoraxis).
            nv:put("targ/euler/lan", sel:lan).
            nv:put("targ/euler/aop", sel:argumentofperiapsis).
            nv:put("targ/euler/mae", sel:meananomalyatepoch).
            nv:put("targ/euler/epoch", sel:epoch).
            nv:put("targ/body", sel:body:name). }

        else {
            return targ:clr(). }

        return 0. }).

    targ:add("clear", {
        nv:clr("targ").
        set targ:target to "".
        set targ:orbit to "".
        return 0. }).

    // local sma is body:radius + (apo + peri)/2.
    // local ecc is abs(apo - peri) / (2*sma).

    targ:add("wait", {
        if hastarget { return targ:save(). }
        io:say("Please select target", false).
        return 5. }).

    local function init {

        local temp_list is list().
        local item is "".
        list targets in temp_list.
        for item in temp_list
            vessel_names:add(item:name).

        list bodies in temp_list.
        for item in temp_list
            body_names:add(item:name).

        if hastarget return targ:save(target).

        if nv:has("targ/name") {
            local n is nv:get("targ/name").
            if targ_names:contains(n)
                return targ:save(n).
            nv:clr("targ/name"). }

        local o is ship:orbit.

        local b is body(nv:get("targ/body", o:body:name)).
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

        return targ:save(o). }

    targ:add("target", "").
    targ:add("orbit", "").
    init(). }
