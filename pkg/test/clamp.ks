@LAZYGLOBAL off.
{   parameter pkg is lex().

    local test is import("test").
    local isnan is test:isnan.

    local NaN is unsafe(0/0).
    local Inf is unsafe(1/0).

    function clamp_case { parameter lo, hi, in, exp.
        local obs is clamp(lo, hi, in).
        if obs = exp
            return.
        if isnan(obs) and isnan(exp)
            return.
        test:fail("clamp("+lo+","+hi+","+in+") -> "+obs+", should be "+exp). }

    function clamp_cases { // test std.ks clamp() function
        clamp_case(1,10,5,5).
        clamp_case(1,10,1,1).
        clamp_case(1,10,10,10).
        clamp_case(1,10,0,1).
        clamp_case(1,10,11,10).
        clamp_case(1,10,NaN,NaN).
        clamp_case(1,10,Inf,10).
        clamp_case(1,10,-Inf,1). }

    pkg:add("go", clamp_cases).
}