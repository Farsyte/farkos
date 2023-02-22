@LAZYGLOBAL off.
{   parameter radar is lex(). // Calibrated Radar Altimeter
    local nv is import("nv").

    // kOS "alt:radar" does not read zero when we are
    // sitting on the launchpad.
    // - Mk.1 capsule only, it reads 0.411 m
    // - add TD-12 and Flea, it reads 2.225 m
    //
    // During launch, we want to have a calibrated value
    // that is zero before ignition, to use to decide if
    // we have cleared the launchpad. Do this by calilbrating
    // the zero point on the first call.
    //
    // When attempting a hoverslam, we need to recalibrate
    // based on the launch configuration. The mission will
    // have to determine calibration data before launch, and
    // recalibrate before it is needed during landing.

    radar:add("cal", { parameter a is alt:radar.                // report radar calibration value
        return nv:get("radar/zero", a, true). }).

    radar:add("recal", { parameter a is alt:radar.              // set radar calibration value
        nv:put("radar/zero", a).
        return a. }).

    radar:add("alt", {                                          // report altitude above calibration point
        return round(alt:radar - radar:cal(), 3). }). }