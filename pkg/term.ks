@LAZYGLOBAL off.
{   package term is lex(). // console terminal interface

    term:add("open", {                  // manipulate the debug console.
        parameter w is terminal:width.
        parameter h is terminal:height.
        set terminal:height to h.
        set terminal:width to w.
        if career():candoactions
            core:doAction("open terminal", true). }).
}
