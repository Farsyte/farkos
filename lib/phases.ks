
// BG_STAGER: A background task for automatic staging.
// Generally, stages if all the engines this would discard
// have flamed out. Stops at stage zero or when the engine
// list is empty. Does not stage if radar altitude is tiny
// and we have no thrust, so we do not "autolaunch" but we
// DO properly manage the "stage 5 lights engines, stage 4
// releases the gantry" configuration.

function bg_stager {
    if alt:radar<100 and availablethrust<=0 return 1.
    local s is stage:number. if s<1 return 0.
    list engines in engine_list.
    if engine_list:length<1 return 0.
    for e in engine_list
        if e:decoupledin=s-1
            if not e:flameout
                return 1.
    if stage:ready
        stage.
    return 1.
}
