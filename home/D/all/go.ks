@LAZYGLOBAL off.
{   parameter go. // GO script for "D/all" stacks.

    // import all packages.

    local ctrl is import("ctrl").
    local dbg is import("dbg").
    local std_go is import("go").
    local hill is import("hill").
    local hover is import("hover").
    local io is import("io").
    local lamb is import("lamb").
    local lambert is import("lambert").
    local match is import("match").
    local memo is import("memo").
    local mission is import("mission").
    local mnv is import("mnv").
    local nv is import("nv").
    local phase is import("phase").
    local plan is import("plan").
    local predict is import("predict").
    local radar is import("radar").
    local rdv is import("rdv").
    local scan is import("scan").
    local sch is import("sch").
    local seq is import("seq").
    local targ is import("targ").
    local task is import("task").
    local term is import("term").
    local visviva is import("visviva").

    go:add("go", {
        io:say(LIST(
            "GO main import test complete",
            "for "+ship:name+",",
            "releasing control.")). }). }