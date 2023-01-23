
// MISSION_BG: Start a background task running.
// The provided function is called repeatedly; its return
// value is the delay until the next call. The loop continues
// as long as the value returned is positive.

function mission_bg { parameter fn.
    local next_t is time:seconds.
    when time:seconds > next_t then {
         local dt is fn().
         if dt > 0 {
             set next_t to time:seconds + dt.
             return true.
         }
         return false.
    }
}
