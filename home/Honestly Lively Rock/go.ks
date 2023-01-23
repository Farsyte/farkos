say("PROJECT: Honestly Lively Rock").

loadfile("mission").
loadfile("phases").

lock steering to facing.

mission_bg(bg_stager@).

wait until availablethrust>0.           // wait for me to push SPACE.
wait until alt:radar>50.                // wait until we are in the air.
lock steering to heading(90, 45).       // pitch over toward the water.

wait until verticalspeed<0.             // when we start coming back down,
lock steering to srfretrograde.         // steer so we come in bottom-first.

wait until alt:radar<2000.              // when we are low enough,
wait until airspeed<200.                // and we are slow enough,
lock steering to up.                    // orient vertically,
stage.                                  // and deploy the parachute.
wait until alt:radar<100.               // maintain control until below 100m.