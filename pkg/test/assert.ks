@LAZYGLOBAL off.
{   parameter pkg is lex().

    local test is import("test").
    local isinf is test:isinf.

    function assert_case { parameter cond.
        local obs is unsafe(assert(cond)).
        if cond {
            if (obs=0)
                return.
            test:fail("assert("+cond+") returned "+obs+", expected zero").
            return. }

        if isinf(obs)
            return.
        test:fail("assert("+cond+") returned "+obs+", expected Inf").
        return. }

    function assert_cases {
        assert_case(true).
        assert_case(false). }

    pkg:add("go", {
        assert_cases(). }).
}