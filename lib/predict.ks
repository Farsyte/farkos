// Orbital Prediction
//
// Encapsulate positionat calls: it is indeed
// correct to subtract CURRENT body position
// from the predicted position of the ship or
// the target, to get the Body-centered

function predict_pos {          // predict Body->Target vector a time t.
    parameter t is time:seconds.    // 1st parameter is time (default to now)
    parameter o is target.          // 2nd parameter is orbitable (default to target)
    return positionat(o, t) - body:position. }
function predict_vel {          // predict Body-relative Target velocity at time t
    parameter t is time:seconds.    // 1st parameter is time (default to now)
    parameter o is target.          // 2nd parameter is orbitable (default to target)
    return velocityat(o, t):orbit. }
function predict_pos_err {      // predict Target->Ship distance at time t
    parameter t is time:seconds.    // 1st parameter is time (default to now)
    parameter o is target.          // 2nd parameter is orbitable (default to target)
    parameter s is ship.            // 3rd parameter is orbitable (default to ship)
    local sp is predict_pos(t, s).
    local op is predict_pos(t, o).
    local pe is op-sp.
    return pe:mag. }.