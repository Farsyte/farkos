@lazyglobal off.
wait 3.
if homeconnection:isconnected {
    compile "0:/farkos.ks" to "0:/farkos.ksm".
    copypath("0:/farkos.ksm", "").
}
if exists("farkos") runpath("farkos").
import("go")().
print "farkos: vessel control software terminated.".
