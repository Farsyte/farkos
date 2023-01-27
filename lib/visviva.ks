// Computations based on the Vis-Viva equation:
//     v^2/mu = 2/r - 1/a
//
// See notes on derivation of the above,
// based on:
//     soe = v^2/2 - mu/r               [specific orbital energy]
//
//     V1*R1 = V2*R2                    [kepler's 2nd law]
//         where V1 and V2 are the LATERAL velocity magnitudes.

// Compute orbital velocity in orbital relative frame.
// Returns a vector where
// - vec:x is the radial component of the velocity
// - vec:z is the lateral comoponent of the velocity
// - vec:mag is the speed along the orbit
// Reverse the sign of vec:x if you are asking about a
// point on the orbit that is descending.

function visviva_vec {
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
    local total_v2 is b:mu*(2/r - 1/a).

    // Compute the (lateral) velocity at periapsis.
    local rperi is r0 + min(h2, h3).
    local vperi is sqrt(abs(b:mu*(2/rperi - 1/a))).

    // Compute the lateral velocity at r.

    local lmag is rperi*vperi/r.
    local rmag is sqrt(abs(total_v2 - lmag^2)).

    local vec is V(rmag, 0, lmag).
    return vec.
}


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
