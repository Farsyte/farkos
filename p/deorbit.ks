export({
    parameter desired_periapsis.

    lock angle_error to vang(facing:vector, retrograde:vector).
    set max_angle_error to 15.
    lock throttle to max(0.01, min(1, 1 - angle_error / max_angle_error)).

    wait until maxthrust < 0.01 or periapsis <= desired_periapsis.

    lock throttle to 0.
}).
