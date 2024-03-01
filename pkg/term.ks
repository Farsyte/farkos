@LAZYGLOBAL off.
{   parameter term is lex().            // console terminal interface

    term:add("open", {                  // display (and maybe resize) the text console.
        parameter w is terminal:width.
        parameter h is terminal:height.
        set terminal:height to h.
        set terminal:width to w.
        if career():candoactions
            core:doAction("open terminal", true). }).
}
