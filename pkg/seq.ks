{   parameter seq is lex(). // seq: task sequencer

    // This package manages the main mission sequence, which is a linear
    // list of steps to be accomplished by the mission, in order. Each step
    // returns a value that indicates either to run it again (and how long
    // to wait before doing so), or to go on to the next task (with a possible
    // delay before the next task).
    //
    // Missions can append to the list.
    //
    // Missions rebuild the list after each boot. In theory, a mission that
    // has reached a significant stage could make a note of it, and reboot
    // to construct a completely different mission plan. HOWEVER, note that
    // the index into the list is maintained in nonvolatile storage, so if
    // you build such a system, you must also execute a "jump" to assure that
    // the phase number is sane for the changed plan.

    local sch is import("sch").
    local nv is import("nv").
    local io is import("io").
    local dbg is import("dbg").

    local phase_list is list().
    local phase_next is 0.
    local phase_name is "".
    local printed_phase_name is "".

    seq:add("do", { parameter l.            // append entry (or entries) to main sequence

        // Add work to the mission main sequence.
        //
        // Normally called with a Function Delegate, which will be
        // appended to the list; the function should return a floating
        // point value as described above.
        //
        // If called with a List, recursively calls itself with each
        // element of the list in order. Note that this allows, in theory,
        // managing sections of a mission as lists of steps, and having the
        // main mission builder just add those lists to the plan.
        //
        // If called with a String, inserts a task into the plan that
        // sets that string as the current mission phase name; the support
        // function handles storing to nonvolatile storage, printing it to
        // the console, and displaying it on the HUD.
        //
        // If called with anything else, a nastygram is placed on the HUD and
        // in the console, then the errant value is ignored.

        if l:istype("Delegate") { phase_list:add(l). return.}
        if l:istype("String") { seq:do({ return sayname(l). }). return. }
        if l:istype("List") { for e in l seq:do(e). return. }
        io:say("seq:do handling TBD for <"+l:typename+"> "+l). }).

    seq:add("go", {                         // start the main sequence. activates SCH:EXECUTE.

        // Turn over control to the main mission sequence execution engine.
        //
        // The current implementation does this by adding the run_phase function
        // as a scheduled task, and turning control over to the scheduled task
        // execution engine.

        sch:schedule(time:seconds, run_phase@).
        sch:execute(). }).

    local function sayname { parameter n.             // display and store label, if it changed.

        // This local function is the support code that handles setting
        // a mission phase name. It is used directly from the mission plan
        // to change names, and is called when we start to report any name
        // that was set before we rebooted.

        if printed_phase_name=n return.
        set printed_phase_name to n.
        nv:put("seq/phase/name", n).
        io:say("SEQ: "+n).
        return 0. }.

    local function run_phase {

        // Scheduled task implementing the Sequencer.
        //
        // Locate and run the proper task from the mission task list.
        // If the return value was positive, return to the scheduler,
        // so we run the current phase again (or, if a jump was called,
        // the target of the jump). Otherwise, increment the current phase
        // number. If the value was negative, have the sceduler wait for
        // the negative of it; if the return value was negative, have it
        // call us in a short time.
        //
        // Note that returning zero would cause us to stop running, not
        // something we want to have happen.

        local p is seq:phase().
        set phase_next to p+1.
        local dt is phase_list[p]().
        if dt>0 return dt.
        nv:put("seq/phase/number", phase_next).
        return max(1/1000, -dt). }

    seq:add("pname", {                      // return most recent mission phase label

        // Report the mission phase name most recently set by the plan.

        return nv:get("seq/phase/name", ""). }).

    seq:add("phase", {                      // return current mission phase number

        // report the current mission phase number, clamped to be a valid
        // index into the mission plan list.

        return max(0,min(phase_list:length-1,nv:get("seq/phase/number"))). }).

    seq:add("jump", {                       // set next mission phase number
        parameter n, val is 0.

        // Set the next mission phase number to the N given, then return
        // the value given in the second parameter.
        //
        // Note that if this is used to return from a step, returning a positive
        // value will proceed to step N after that delay; if N is zero or negative,
        // then we proceed to step N+1 after delaying for -val.
        //
        // Code like
        //      return seq:jump(nv:get("plan/burnstep"), 1.0).
        // should be expected to be comon.

        set phase_next to n.
        nv:put("seq/phase/number", phase_next).
        return val. }).
}