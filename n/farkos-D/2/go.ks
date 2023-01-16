{
    local pof is import("pof").

    local launch_azimuth is 90.
    local orbit_altitude is 72000.

    function go {
        pof:launch(launch_azimuth).
        pof:stager().
        pof:ascend(launch_azimuth, orbit_altitude).
        pof:coastu(30).
        pof:circ(5,5,1).
        pof:pause().
        pof:deorbit(20000).
        pof:decel(60000,50000).
        pof:chute(4000).
    }

    export(go@).
}