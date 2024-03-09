@LAZYGLOBAL off.
{   parameter angle is lex().

    local test is import("test").
    local isnan is test:isnan.
    local isinf is test:isinf.

    function ua_case { parameter input.
        local obs is ua(input).
        if isnan(input) and isnan(obs)
            return.
        if isinf(input) and isnan(obs)
            return.
        if isinf(-input) and isnan(obs)
            return.
        if obs < 0
            test:fail("ua("+input+") -> "+obs+": should not be negative").
        if obs >= 360
            test:fail("ua("+input+") -> "+obs+": should not be >= 360.").
        if not (mod(input - obs, 360) = 0)
            test:fail("ua("+input+") -> "+obs+": difference is not a multiple of 360"). }

    function ua_cases {
        ua_case(0.0).
        ua_case(1.0).
        ua_case(359.0).
        ua_case(360.0).
        ua_case(361.0).
        ua_case(-1.0).
        ua_case(-359.0).
        ua_case(-360.0).
        ua_case(-361.0).
        unsafe({
            ua_case(0/0).
            ua_case(1/0).
            ua_case(-1/0). }). }

    function sa_case { parameter input.
        local obs is sa(input).
        if isnan(input) and isnan(obs)
            return.
        if isinf(input) and isnan(obs)
            return.
        if isinf(-input) and isnan(obs)
            return.
        if obs < -180
            test:fail("sa("+input+") -> "+obs+": should not be < -180").
        if obs > 180
            test:fail("sa("+input+") -> "+obs+": should not be > +180").
        if not (mod(input - obs, 360) = 0)
            test:fail("sa("+input+") -> "+obs+": difference is not a multiple of 360"). }

    function sa_cases {
        sa_case(0.0).
        sa_case(1.0).
        sa_case(359.0).
        sa_case(360.0).
        sa_case(361.0).
        sa_case(-1.0).
        sa_case(-359.0).
        sa_case(-360.0).
        sa_case(-361.0).
        unsafe({
            sa_case(0/0).
            sa_case(1/0).
            sa_case(-1/0). }). }

    angle:add("go", {
        ua_cases().
        sa_cases(). }).
}
