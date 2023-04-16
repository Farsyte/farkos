@LAZYGLOBAL off.

// this code can be demonstrated via boot/sa.ks
// by setting the vessel name to demo/autostager_when.

// The start_stager() function returns the task lexicon provided by
// the when_then_svc, allowing the caller to pause, resume, or cancel
// the staging service. It is possbile that "start_stager" methods
// from other wrappers will have different capabilities.

runpath("0:sa/when_then_svc").
runpath("0:sa/autostager_task").

// KNOWN ISSUES IN THIS APPROACH:
// ** It uses a WHEN..THEN construct, imposing inherent load
//    at the top of every physics tick.

global function start_stager {
    return when_then_svc(maybe_stage@).
}
