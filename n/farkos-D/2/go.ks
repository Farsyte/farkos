{
    local farkos is import("farkos").
    local pof is import("pof").

    local launch_azimuth is 90.
    local orbit_altitude is 72000.

    function go {

        farkos:ev("Launching in one minute.").

        wait 55.
        set warp to 0.
        wait 5.

        stage.

        pof:launch(launch_azimuth).
        wait until ship:maxthrust = 0.
        pof:stager().
        pof:ascend(launch_azimuth, orbit_altitude).
        pof:coastu(30).
        pof:circ(5,5,1).
        pof:pause(30).
        pof:deorbit(20000).
        pof:decel(60000,50000).
        pof:chute().
    }

    export(go@).
}