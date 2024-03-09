@LAZYGLOBAL off.
{   parameter pkg is lex().

    local test is import("test").
    local isnan is test:isnan.

    local NaN is unsafe(0/0).
    local Inf is unsafe(1/0).

    function sgn_case { parameter input, exp.
        local obs is sgn(input).
        if exp = obs
            return.
        if isnan(exp) and isnan(obs)
            return.
        test:fail("sgn("+input+") -> "+obs+": expected "+exp). }

    function sgn_cases {
        sgn_case(-100.0, -1).
        sgn_case(-1, -1).
        sgn_case(-0.001, -1).
        sgn_case(0.000, 0).
        sgn_case(0.001, 1).
        sgn_case(1, 1).
        sgn_case(100.0, 1).

        // Disable the NaN safety built into kOS while testing
        // that SGN has a predictable result when passed NaN and Inf.
        unsafe({
            sgn_case(NaN, NaN).
            sgn_case(Inf, 1).
            sgn_case(-Inf, -1). }). }

    pkg:add("go", sgn_cases).
}