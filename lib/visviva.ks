// Computations based on the Vis-Viva equation:
//     v^2/mu = 2/r - 1/a
//
// See notes on derivation of the above,
// based on:
//     soe = v^2/2 - mu/r               [specific orbital energy]
//
//     V1*R1 = V2*R2                    [kepler's 2nd law]
//         where V1 and V2 are the LATERAL velocity magnitudes.


// Compute scalar orbital velocity
// using vis-viva: v^2/2 = 2/r - 1/a
// NOTE: this is velocity ALONG the orbit.

function visviva_v {
    parameter r1.               // current radius.
    parameter r2 is r1.         // periapsis (or apoapsis) radius.
    parameter r3 is r1.         // apoapsis (or periapsis) radius.
    parameter mu is body:mu.    // gravitational field strength
    return sqrt(abs(2*mu*(1/r1 - 1/(r2+r3)))).
}
