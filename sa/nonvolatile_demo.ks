@LAZYGLOBAL OFF.

// this demo can be run via boot/sa.ks
// by setting the vessel name to demo/nonvolatile.

runpath("0:sa/nonvolatile").

local bootcount is nv_get("bootcount") + 1.
nv_put("bootcount", bootcount).

print "bootcouunt is "+bootcount.
if bootcount < 3 {
    print "rebooting in 5 seconds to check bootcount update.".
    wait 5.
    reboot.
}

nv_put("fred", 1).
nv_put("fred/dave", 2).
nv_put("fred/bill", 3).

print "created fred, fred/dave, and fred/bill.".

local file_list is list().
list files in file_list.
print "files found:".

function print_files {
    parameter pfx. // relative path from root to dir
    parameter dir. // lexiucon of VolumeFile or VolumeDirectory
    local names is dir:lexicon:keys.
    local n is "".
    for n in names {
        local val is dir:lexicon[n].
        set n to pfx+"/"+val:name.
        if val:isfile print val:size:tostring:padleft(7)+" "+n.
        else print_files(n, val).
    }
}

print_files("", volume(1):root).
print "fred: "+nv_get("fred").
print "fred/dave: "+nv_get("fred/dave").
print "fred/bill: "+nv_get("fred/bill").

nv_clr("fred"). print "effects of nv_clr(""fred""):".
print_files("", volume(1):root).
print "fred: "+nv_get("fred").
print "fred/dave: "+nv_get("fred/dave").
print "fred/bill: "+nv_get("fred/bill").

nv_put("fred", 1).
nv_put("fred/dave", 2).
nv_put("fred/bill", 3).

nv_clr_dir("fred"). print "effects of nv_clr_dir(""fred""):".
print_files("", volume(1):root).
print "fred: "+nv_get("fred").
print "fred/dave: "+nv_get("fred/dave").
print "fred/bill: "+nv_get("fred/bill").
