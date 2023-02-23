@LAZYGLOBAL off.

{
    parameter scan is lex(). // unidirectional hillclimb with backstep

    scan:add("init", {
        parameter fitness. // fitness function we will maximize
        parameter fitincr. // function to increment the state vector
        parameter fitfine. // function to reduce step size
        parameter fitstate. // lexicon to present to above delegates
        set fitstate["score"] to 0. // make sure it has a "score" suffix.
        return lex (
            "candidates", list(), // memory of recent evaulations [0] is eldest
            "fitness", fitness,
            "fitincr", fitincr,
            "fitfine", fitfine,
            "fitstate", fitstate ). }).

    // scanner:step(scanner): evaluate one more candidate.
    // return true if scanner:fitstate is the located maximum.
    scan:add("step", { parameter scanner.
        local c is scanner:candidates.
        local a is scanner:fitstate.
        set a["score"] to scanner:fitness(a).
        c:add(a:copy()).
        if c:length=3 {
            if c[0]:score < c[1]:score and c[1]:score >= c[2]:score {
                if scanner:fitfine(c[0])
                    return true.
                set scanner:fitstate to c[0].
                set scanner:candidates to list().
                return false. }

            // we have three samples but do not see a local maximum.
            c:remove(0). }

        // fitincr returns true if we have to stop now.
        return scanner:fitincr(scanner:fitstate). }).
}