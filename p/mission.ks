{
    local farkos is import("farkos").
    local persist is import("persist").

    local mission is lex(
        "abort_mission", abort_mission@,
        "add_phase", add_phase@,
        "add_phases", add_phases@,
        "get_phase", get_phase@,
        "set_phase", set_phase@,
        "next_phase", next_phase@,
        "go", go@, "bg", bg@).
    export(mission).

    local phase_func is list().

    local abort_flag is false.

    function phase_of {
        parameter phase.
        return choose phase if phase:istype("Delegate")
            else import("phases"):_get(phase).
    }

    function abort_mission {
        set abort_flag to true.
    }

    function add_phase {
        parameter phase_nm.
        parameter phase_fn is phase_of(phase_nm).
        phase_func:add(phase_fn).
        return phase_func:length.
    }

    function add_phases {
        parameter phase_list.
        for p in phase_list {
            add_phase(p).
        }
    }

    function get_phase {
        return persist:get("phase", 0, true).
    }
    function set_phase { parameter phase.
        persist:put("phase", phase).
    }
    function next_phase {
        set_phase(get_phase()+1).
    }

    function go {
        set abort_flag to false.
        local next_mission_event is time:seconds + 1.
        when time:seconds >= next_mission_event then {
            if abort_flag return false.
            local phase_no is clamp(0, phase_func:length-1, persist:get("phase")).
            persist:put("phase", phase_no).
            set next_mission_event to time:seconds
                + clamp(0, 10, phase_func[phase_no]()).
            return true.
        }
    }

    function bg {
        parameter phase_nm.
        parameter phase_fn is phase_of(phase_nm).
        local next_background_at is time:seconds + 1.
        when time:seconds >= next_background_at then {
            if abort_flag return false.
            local dt is phase_fn().
            if dt > 0 {
                set next_background_at to time:seconds + dt.
                return true.
            }
            return false.
        }
    }
}