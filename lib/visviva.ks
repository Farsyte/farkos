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
    parameter h1.           // current altitude.
    parameter h2 is h1.     // periapsis (or apoapsis) altitude.
    parameter h3 is h1.     // apoapsis (or periapsis) altitude.
    parameter b is body.    // which body we are orbiting.

    // KSP (and kOS) use ALTITUDE, but math needs RADIUS,
    // so we have to add the radius of the body.
    local r0 is b:radius.

    // Math wants current radius.
    local r is r0 + h1.           // current radius

    // Math wants Semi-Major Axis,
    // which is half of the periapsis plus apoapsis radii.
    local a is r0 + (h2+h3)/2.    // semi-major axis

    // Compute the velocity at r
    return sqrt(abs(b:mu*(2/r - 1/a))).
}
