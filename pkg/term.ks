{   package term is lex(). // console terminal interface

    // term(w,h): open the console terminal.
    // optional parameters can be used to set the size.
    term:add("open", {
        parameter w is terminal:width.
        parameter h is terminal:height.
        set terminal:height to h.
        set terminal:width to w.
        if career():candoactions
            core:doAction("open terminal", true).
    }).
}