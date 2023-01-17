{
    local farkos is import("farkos").
    local bist is import("bist").
    local persist is import("persist").

    function go {

        // uncomment this if the BIST seems to be malfunctioning.
        // bist:selftest().

        bist:f("initial presence of unpersisted data",
            persist:has("neverset")).

        bist:eq("value of unpersisted data (default to zero).",
            0, persist:get("neverset")).

        bist:eq("value of unpersisted data (default specified).",
            37, persist:get("neverset", 37)).

        bist:f("presence of unpersisted data after get",
            persist:has("neverset")).

        persist:put("magic", 42).

        bist:t("presence of unpersisted data after setting another item",
            persist:has("magic")).

        bist:eq("get returns set value",
            42, persist:get("magic")).

        local startcount is 1 + persist:get("startcount").
        persist:put("startcount", startcount).
        print "startcount is " + startcount.

        if startcount = 1 {
            persist:put("phase", 1).
            print "persisted phase is set to 1. Please cycle power to continue.".
        } else {
            bist:t("phase is present on startcount " + startcount,
                persist:has("phase")).
            bist:eq("phase is correct on startcount " + startcount,
                1, persist:get("phase")).

            print "please cycle power if you want to run this again.".
        }
    }

    export(go@).
}
