@LAZYGLOBAL off.
{   parameter scan is lex(). // unidirectional hillclimb with backstep

    // To use this:
    // - define fitness, a function of a state, to be maximized.
    // - define fitincr, which increments (and returns) the state.
    // - define fitfine, which reduces step sizes
    // - construct the initial state vector
    // - use scan:init to package up the scanner state.
    // - call step until it returns true, doing other things between calls.
    // - scanner:failed will be true if we have not found a maximum.
    // - scanner:result will have the state that has maximum fitness.
    // Note that each time we find a local maximum at any grid size,
    // the "failed" and "result" values are updated, so if problems
    // arise in a refined pass, the caller will see the earlier estiamate.
    //
    // There are several ways for the caller to indicate failure.
    // - fitness returning anything that is not a Scalar.

    local function copyof { parameter val.
        return choose val if val:istype("Scalar") else val:copy(). }

    scan:add("init", {      // create the scanner state lexicon.
        parameter fitness.  // fitness function we will maximize
        parameter fitincr.  // function to increment the state vector
        parameter fitfine.  // function to reduce step size
        parameter fitstate. // state to provide to above.

        local c is list().

        local scanner is lex(
            "result", "fail",
            "failed", true ).

        scanner:add("step", {       // the preconfigured scanner delegate we will return.

            // termination case 1: fitness says to stop searching.
            local score is fitness(fitstate).

            // add scalar scores and state to the results we are watching.
            if score:istype("Scalar")
                c:add(list(score, copyof(fitstate))).

            // The string "halt" terminates the process.
            if score:istype("String") and score="halt"
                return true.

            // see if we are bracketing a maximum.
            // NOTE: if all three samples are the same,
            // treat the middle as a local maximum.
            if c:length=3 {
                local sc is c[1][0].
                local il is sc - c[0][0].
                local ir is sc - c[2][0].

                if il<0 or ir<0
                    c:remove(0).    // not bracketing a maximum. make room for next.

                else {              // bracketing a maximum.
                    // register the bracketed maximum as a reasonable result
                    set scanner:failed to false.
                    set scanner:result to c[1][1].
                    // rewind to the sample before the maximum
                    set fitstate to c[0][1].
                    // refine the search grid.
                    // termination case 2: fitfine says no further refinement
                    if fitfine(fitstate, max(il,ir))
                        return true.
                    // keep only the old pre-max result,
                    // and set up to increment from it.
                    until c:length < 2 c:remove(1).
                    set c[0][1] to copyof(fitstate). } }

            // step to the next grid point for searching.
            set fitstate to fitincr(fitstate).
            return false. }).

        return scanner. }).
}
