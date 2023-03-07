@LAZYGLOBAL off.
{
    parameter visviva is lex().         // apply v^2/mu = 2/r1 - 1/a

    // see doc/visviva.pdf for derivation of the vis-viva equation used here.

    visviva:add("v", {                  // compute v for r1, rp, ra, mu.
        parameter r1.                   // current radius.
        parameter rp is r1.             // periapsis (or apoapsis) radius.
        parameter ra is r1.             // apoapsis (or periapsis) radius.
        parameter mu is body:mu.        // gravitational field strength
        local a is (rp+ra)/2.           // semi-major axis
        local v2 is mu*(2/r1 - 1/a).    // v^2/mu = 2/r1 - 1/a
        return choose sqrt(v2) if v2>0 else 0. }).
}
