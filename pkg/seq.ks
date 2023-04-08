{   parameter seq is lex(). // seq: task sequencer

    local sch is import("sch").
    local nv is import("nv").
    local io is import("io").
    local dbg is import("dbg").

    local phase_list is list().
    local phase_next is 0.
    local phase_name is "".
    local printed_phase_name is "".

    seq:add("pname", {                      // return most recent mission phase label
        return nv:get("seq/phase/name", ""). }).

    seq:add("phase", {                      // return current mission phase number
        return max(0,min(phase_list:length-1,nv:get("seq/phase/number"))). }).

    seq:add("jump", {                       // set next mission phase number
        parameter n, val is 0.
        set phase_next to n.
        nv:put("seq/phase/number", phase_next).
        return val. }).

    local function sayname { parameter n.             // display and store label, if it changed.
        if printed_phase_name=n return.
        set printed_phase_name to n.
        nv:put("seq/phase/name", n).
        io:say("SEQ: "+n).
        return 0. }.

    local function run_phase {
        local p is seq:phase().
        set phase_next to p+1.
        local dt is phase_list[p]().
        if dt>0 return dt.
        nv:put("seq/phase/number", phase_next).
        return max(1/1000, -dt). }

    seq:add("do", { parameter l.            // append entry (or entries) to main sequence
        if l:istype("Delegate") { phase_list:add(l). return.}
        if l:istype("String") { seq:do({ return sayname(l). }). return. }
        if l:istype("List") { for e in l seq:do(e). return. }
        io:say("seq:do handling TBD for <"+l:typename+"> "+l). }).

    seq:add("go", {                         // start the main sequence. activates SCH:EXECUTE.
        sch:schedule(time:seconds, run_phase@).
        sch:execute(). }).
}