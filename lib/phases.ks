
// BG_STAGER: A background task for automatic staging.
// Generally, stages if all the engines this would discard
// have flamed out. Disabled at low altitude, stops at
// stage zero or when the engine list is empty.

function bg_stager {
    if alt:radar<100 return 1.
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
