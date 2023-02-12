// MUN RETRO:
//
// starting with a node that puts us onto a mun transfer orbit,
// adjust it to get a "free return" trajectory where we swing
// in front of mun, around its back, and come back out heading
// back toward kerbin, such that our return from kerbin will
// have an apoapsis in the 35km to 60km range.

function mun_retro_cond {
    if not hastarget return false.
    print "mun_retro_cond: target is "+target_name.
    return true. }

function mun_retro_start { }

function mun_retro_step {
    return 1. }

function mun_retro_stop { }
