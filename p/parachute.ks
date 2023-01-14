export({
    parameter desired_deploy_altitude is 5000, maximum_speed is 250.
    wait until altitude < desired_deploy_altitude and ship:velocity:surface:mag < maximum_speed.
    GEAR ON.
    until false {
        wait 2.
        wait until stage:ready. stage.
    }
}).
