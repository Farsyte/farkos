{   parameter io is lex(). // I/O Library

    // IO:SAY(m,e): present a m.
    // It is intended that some missions may want to provide a
    // replacement implementaton for std:say(m,e).
    io:add("say", {
        parameter m, e is true.
        if m:istype("List") for s in m io:say(s, e).
        else hudtext(m,5,2,24,WHITE,e).
    }).
}
