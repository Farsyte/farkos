@LAZYGLOBAL off.
{
    parameter visviva is lex().         // apply v^2/mu = 2/r - 1/a

    // see doc/visviva.pdf for derivation of the vis-viva equation used here.

    visviva:add("v", {                  // compute v for r, rp, ra, mu.
        parameter r.                    // current radius.
        parameter rp is r.              // periapsis (or apoapsis) radius.
        parameter ra is r.              // apoapsis (or periapsis) radius.
        parameter mu is body:mu.        // gravitational field strength
        local a is (rp+ra)/2.           // semi-major axis
        local v2 is mu*(2/r - 1/a).    // v^2/mu = 2/r - 1/a
        return choose sqrt(v2) if v2>0 else 0. }). }