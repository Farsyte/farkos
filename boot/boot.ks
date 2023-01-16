@LAZYGLOBAL OFF.
wait 3.
if homeconnection:isconnected {
    compile "0:/farkos.ks" to "0:/ksm/farkos.ksm".
    copypath("0:/ksm/farkos.ksm", "").
}
if exists("farkos") runpath("farkos").
import("go")().
