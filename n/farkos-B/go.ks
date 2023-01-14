print "loading microcode for farkos-B/1".
export({

    if availablethrust <= 0
        print "press SPACEBAR to launch".
    wait until availablethrust > 0.

    set Cs to facing.
    lock steering to Cs.
    lock throttle to 1.

    stage.

    wait until ship:velocity:surface:mag > 10.

    set Cs to heading(90, 90).

    wait until altitude > 150.

    set Cs to heading(90, 45).

    wait until ship:verticalspeed < 0.

    stage.
    set Cs to heading(90, 90).
    wait 3.
    unlock steering.

    wait until altitude < 2000.
    stage.

}).