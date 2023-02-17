{   parameter goal. // configure goals for this vessel.

    // COMSAT ONE:
    // - prepared for ∫INTEGRAL⋅∂s
    // - apoapsis: 6,364,701 m
    // - periapsis: 6,182,948 m
    // - inclination: 0 °
    // must have an antenna
    // must be able to generate power
    // must have a mystery goo unit
    //
    // transfer from 80x80 to this orbit
    // will take about 1000 Δv.

    goal:add("periapsis", 6182948).
    goal:add("apoapsis", 6364701). }
