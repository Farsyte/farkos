loadfile("persist").
loadfile("debug").
if not persist_has("rescue_target") {
    until hastarget {
        set remind to time:seconds + 5.
        say("Please set TARGET.", false).
        wait until time:seconds>remind or hastarget.
    }
    persist_put("rescue_target", target).
}