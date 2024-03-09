@LAZYGLOBAL off.
{   parameter pkg is lex().
    local fmt is import("fmt").

    // TODO: provide actual "check that result is correct" code.

    function s_cases {
        print("fmt:s ...").
        print("["+fmt:s("xy")+"]").
        print("["+fmt:s("xy",5)+"]").
        print("["+fmt:s("xy",-5)+"]"). }

    function d_cases {    
        print("fmt:d ...").
        print("["+fmt:d(123)+"]").
        print("["+fmt:d(123,5)+"]").
        print("["+fmt:d(123,-5)+"]").
        print("["+fmt:d(123,5,"0")+"]").
        print("["+fmt:d(123,5,"+")+"]").
        print("["+fmt:d(123,-5,"+")+"]").
        print("["+fmt:d(123,5,"+0")+"]").
        print("["+fmt:d(-123)+"]").
        print("["+fmt:d(-123,5)+"]").
        print("["+fmt:d(-123,-5)+"]").
        print("["+fmt:d(-123,5,"0")+"]").
        print("["+fmt:d(-123,5,"+")+"]").
        print("["+fmt:d(-123,-5,"+")+"]").
        print("["+fmt:d(-123,5,"+0")+"]"). }

    function f_cases {
        print("fmt:f ...").
        print("["+fmt:f(123.511,0,1)+"]").
        print("["+fmt:f(123.511,8,1)+"]").
        print("["+fmt:f(123.511,-8,1)+"]").
        print("["+fmt:f(123.511,8,1,"0")+"]").
        print("["+fmt:f(123.511,8,1,"+")+"]").
        print("["+fmt:f(123.511,-8,1,"+")+"]").
        print("["+fmt:f(123.511,8,1,"+0")+"]").
        print("["+fmt:f(-123.511,0,1)+"]").
        print("["+fmt:f(-123.511,8,1)+"]").
        print("["+fmt:f(-123.511,-8,1)+"]").
        print("["+fmt:f(-123.511,8,1,"0")+"]").
        print("["+fmt:f(-123.511,8,1,"+")+"]").
        print("["+fmt:f(-123.511,-8,1,"+")+"]").
        print("["+fmt:f(-123.511,8,1,"+0")+"]"). }

    pkg:add("go", {
        s_cases().
        d_cases().
        f_cases(). }
}
