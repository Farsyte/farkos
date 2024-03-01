@LAZYGLOBAL off.
{   parameter test is lex().            // testing package.

    local hud is import("hud").         // console output

    local count_fail is 0.              // test state is only a simple fail counter

    test:add("isnan", { parameter val.  // verify NaN-ness during testing.
        if Config:SAFE return false.
        return not(val=val). }).

    test:add("isinf", { parameter val.  // verify Inf-ness during testing.
        if Config:SAFE return false.
        return val = 1/0. }).

    test:add("reset", {                 // reset the test fail counter
        set count_fail to 0. }).

    test:add("fail", { parameter str.
        set count_fail to count_fail + 1.
        hud:say("TEST FAIL: "+str). }).

    test:add("results", {
        if count_fail > 0 {
            hud:say("FAILED "+count_fail+" TEST CASES."). }
        else {
            hud:say("PASSED ALL TEST CASES."). } }).
}
