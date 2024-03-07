@LAZYGLOBAL off.
{   parameter term is lex().            // console terminal interface

    term:add("open", {                  // display (and maybe resize) the text console.
        parameter tw is terminal:width.
        parameter th is terminal:height.
        set terminal:height to th.
        set terminal:width to tw.
        if career():candoactions
            core:doAction("open terminal", true). }).
}
