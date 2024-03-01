@LAZYGLOBAL off.
{   parameter goal. // configure goals for this vessel.

    // R-EO-1 Radar Antenna             1.0 ec/sec
    // MS-1 Multispectral Scanner       0.8 ec/sec
    // HG-5 High Gain Antenna (x2)      51.4 ec/sec when transmitting
    // OX-STAT Photovoltaic Panels      0.3 ec/sec in full light
    //
    // R-EO-1 Radar Antenna             50-500km; >100km ideal.
    // MS-1 Multispectral Scanner       20-250km; >70km ideal.
    //
    goal:add("periapsis", 120000).
    goal:add("apoapsis", 120000).
    goal:add("inclination", 86). }
