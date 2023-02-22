@LAZYGLOBAL off.
{   parameter io is lex(). // I/O Library

    io:add("say", {         // IO:SAY(m,e): display a message.
        // It is intended that some missions may want to provide a
        // replacement implementaton for std:say(m,e).
        parameter m, e is true.
        if m:istype("List") for s in m io:say(s, e).
        else hudtext(m,5,2,24,WHITE,e). }). }
