@LAZYGLOBAL OFF.

// Mission Sequencer.
//
// Each mission is presumed to have exactly one master mission plan
// consisting of a linear list of phases, where we execute each phase
// until it is complete and move along to the next (unless steps are
// taken to jump around in the list).

runpath("0:sa/scheduler").
// global function schedule_call { parameter ut, task. ... }
// global function schedule_runner { ... }

runpath("0:sa/nonvolatile").
// global function nv_has { parameter name. ... }
// global function nv_clr_dir { parameter name. ... }
// global function nv_clr { parameter name. ... }
// global function nv_put { parameter name, value. ... }
// global function nv_get { parameter name, def is 0, commit is false. ... }

local phase_noop is { return 0. }.
local phase_list is list(phase_noop).
local phase_next is 0.
local phase_name is "".

// We have the notion of the Name of the phase we are in.
// This is persisted, is set from the plan, and can be
// obtained by calling sequencer_pname as desired.

global function sequencer_pname {                      // return most recent mission phase label
    return nv_get("seq/phase/name", "").
}

// The mission plan is a simple linear list. sequencer_phase
// returns the current phase number, clipped to be within the
// legal range for the phase list.
//
// This can be used to query the current phase number and save
// it for later, for example, to present to sequencer_jump.
//
// Note that the phase_list always has at least one entry,
// the no-op initialized into it, to assure that we can
// always return a sequencer_phase number that can be used
// to index into the list without crashing.

global function sequencer_phase {                      // return current mission phase number
    local p is nv_get("seq/phase/number").
    local l is phase_list:length-1.
    return max(0,min(l,p)).
}

// Set the phase number in the mission sequencer. phase code
// calling this function should return a positive delay to
// start the indicated phase; or return a zero (or negative)
// value to resume at the phase after the presented value.

global function sequencer_jump {                       // set next mission phase number
    parameter n, val is 0.
    set phase_next to n.
    nv_put("seq/phase/number", phase_next).
    return val.
}

local function sayname { parameter n.                   // display and store label, if it changed.
    // NOTE: in a larger system context, this method would
    // use (or be replaced by) a supplied display and logging
    // mechanism that maybe does a lot more.
    if phase_name=n return.
    set phase_name to n.
    nv_put("seq/phase/name", n).
    if n<>"" print "SEQ: "+n.
    return 0.
}

local function run_phase {
    local dt is phase_list[sequencer_phase()]().
    if dt>0 return dt.
    nv_put("seq/phase/number", 1+sequencer_phase()).
    return max(1/1000, -dt).
}

global function sequencer_do { parameter l.            // append entry (or entries) to main sequence

    // The sequence is built up by the mission script by appending
    // function delegates for each phase via the sequencer_do method.
    if l:istype("Delegate") { phase_list:add(l). return.}

    // As a shortcut, if a string is passed to sequencer_do, it will
    // insert a phase that prints and stores that string as the
    // current phase name.
    if l:istype("String") { sequencer_do({ return sayname(l). }). return. }

    // Also as a shortcut, if a List is passed, it will consider each
    // element of the list in turn.
    if l:istype("List") { for e in l sequencer_do(e). return. }

    print "sequencer_do handling TBD for objects of type: "+l:typename.
}

global function sequencer_go {                         // start the main sequence. activates SCH:EXECUTE.
    schedule_call(time:seconds, run_phase@).
    sayname(sequencer_pname()).
    schedule_runner().
}
