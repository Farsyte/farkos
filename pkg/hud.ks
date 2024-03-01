@LAZYGLOBAL off.
{   parameter hud is lex(). // I/O Library

    hud:add("say", {         // hud:SAY(m,e): display a message.
        // It is intended that some misshudns may want to provide a
        // replacement implementaton for std:say(m,e).
        parameter m, e is true.
        // hud_say(m,e) dislays "m" on the hud, and "e" controls
        // whether the message also appears in the console.
        // If "m" is a list, hud:say recusively applies itself to
        // each member of the list.
        if m:istype("List") for s in m hud:say(s, e).
        else hudtext(m,5,2,24,WHITE,e). }).
}
