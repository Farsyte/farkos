{

    // If anyone does an import("bist") and we can
    // do custom actions, open the terminal.
    // This requires VAB level 3.
    if Career():candoactions
        core:doAction("open terminal", true).

    // bist: Built-In Self Test

    local bist is lex(
        "logline", logline@,
        "result", result@,
        "pass", pass@,
        "fail", fail@,
        "t", t@,
        "f", f@,
        "eval", eval@,
        "eq", eq@,
        "ne", ne@,

        "selftest", selftest@).

    export(bist).

    local logfile is "0:/t/" + ship:name + ".log".

    function logline {
        parameter message.
        print message.
        log message to logfile.
    }

    logline("logging test results to " + logfile).

    function result {
        parameter testcase, expected, observed.
        logline(testcase).
        logline("  expected: " + expected).
        logline("  observed: " + observed).
    }

    function pass {
        parameter testcase, expected, observed.
        result("PASS: " + testcase, expected, observed).
    }

    function fail {
        parameter testcase, expected, observed.
        result("FAIL: " + testcase, expected, observed).
    }

    function t {
        parameter testcase, observed.
        set r to choose "PASS: " if observed else "FAIL: ".
        logline(r + testcase).
    }

    function f {
        parameter testcase, observed.
        set r to choose "FAIL: " if observed else "PASS: ".
        logline(r + testcase).
    }

    function eval {
        parameter testcase, expected, observed, fn.
        if fn(expected, observed) {
            pass(testcase, expected, observed).
        } else {
            fail(testcase, expected, observed).
        }
    }

    function eq {
        parameter testcase, expected, observed.
        return eval(testcase, expected, observed, {
            parameter a, b. return a = b. }).
    }

    function ne {
        parameter testcase, expected, observed.
        return eval(testcase, expected, observed, {
            parameter a, b. return NOT a = b. }).
    }

    function selftest {
        bist:logline("MANUALLY verify bist:logline works.").
        bist:result(
            "checking bist:result",
            "some expected value",
            "some observed value").
        bist:pass(
            "checking bist:pass",
            "some expected value",
            "some observed value").
        bist:fail(
            "checking bist:fail",
            "some expected value",
            "some observed value").
        bist:t("checking bist:t (pass case)", true).
        bist:t("checking bist:t (fail case)", false).
        bist:f("checking bist:f (pass case)", false).
        bist:f("checking bist:f (fail case)", true).
        bist:eval("checking bist:eval (pass case)",
            "some observed value", "some expected value", { parameter a, b.
            bist:logline("in eval test 1, a is " + a).
            bist:logline("in eval test 1, b is " + b).
            return false. }).
        bist:eval("checking bist:eval (fail case)",
            "some observed value", "some expected value", { parameter a, b.
            bist:logline("in eval test 2, a is " + a).
            bist:logline("in eval test 2, b is " + b).
            return true. }).
        bist:eq("checking bist:eq (pass case)", 1, 1).
        bist:eq("checking bist:eq (fail case)", 0, 1).
        bist:ne("checking bist:ne (pass case)", 0, 1).
        bist:ne("checking bist:ne (fail case)", 1, 1).
    }
}