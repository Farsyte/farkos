@LAZYGLOBAL off.
{   parameter memo is lex(). // memoization package

    memo:add("getter", {    // memoize a getter (invariant during a phys tick)
        parameter getter.

        // Some getters will return the same value when called many times
        // during the same tick, and take significant resources to run,
        // and this method will wrap them up so that additional calls will
        // instead just use the value.
        //
        // Many getters should NOT be wrapped in this way. This wrapper is just
        // for getters that do benefit from it.

        local memoized_time is 0.
        local memoized_value is 0.
        return {            // constructed delegate memoizing getter results
            if memoized_time<>time:seconds
                set memoized_value to getter().
            set memoized_time to time:seconds.
            return memoized_value. }. }).
}
