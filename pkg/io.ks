@LAZYGLOBAL off.
{   parameter io is lex(). // I/O Library

    io:add("say", {         // IO:SAY(m,e): display a message.
        // It is intended that some missions may want to provide a
        // replacement implementaton for std:say(m,e).
        parameter m, e is true.
        // io_say(m,e) dislays "m" on the hud, and "e" controls
        // whether the message also appears in the console.
        // If "m" is a list, io:say recusively applies itself to
        // each member of the list.
        if m:istype("List") for s in m io:say(s, e).
        else hudtext(m,5,2,24,WHITE,e). }).
}
