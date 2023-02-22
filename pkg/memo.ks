@LAZYGLOBAL off.
{
    parameter memo is lex(). // memoization package

    memo:add("getter", {    // memoize a getter (invariant during a phys tick)
        parameter getter.
        local memoized_time is 0.
        local memoized_value is 0.
        return {
            if memoized_time<>time:seconds
                set memoized_value to getter().
            set memoized_time to time:seconds.
            return memoized_value. }. }). }
