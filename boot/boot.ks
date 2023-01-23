@LAZYGLOBAL OFF.
if homeconnection:isconnected
    compile "0:/lib/stdlib.ks" to "stdlib.ksm".
runpath("stdlib").
loadfile("go").