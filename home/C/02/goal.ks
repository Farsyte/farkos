@LAZYGLOBAL off.
{   parameter goal. // configure goals for this vessel.

    // COMSAT TWO:
    // - apoapsis: 8638604 m
    // - periapsis: 7897180 m
    // - inclination: 180 °
    // must have an antenna
    // must be able to generate power
    // must have a thermometer
    // must have a science jr

    goal:add("periapsis", 7897180).
    goal:add("apoapsis", 8638604).
    goal:add("inclination", 180). }
