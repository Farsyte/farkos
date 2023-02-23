@LAZYGLOBAL off.

runpath("0:/std").
local scan is import("scan").
local dbg is import("dbg").

local fitstate is lex( "theta", 0 ).

local delta is 15.

local function fitness { parameter state.
    return 1-sin(state:theta-66.6666)^2. }

local function fitincr { parameter state.
    set state:theta to state:theta + delta.
    return state:theta > 720. }

local function fitfine { parameter state.
    set delta to delta/10.
    return delta < 1/1000. }

local scanner is scan:init(fitness@, fitincr@, fitfine@, fitstate).

local itercount is 0.
until scan:step(scanner) {
    set itercount to itercount + 1. }
local oE is OPCODESLEFT.
local tE is time:seconds.
dbg:pv("[done] itercount", itercount).
dbg:pv("[done] fitstate", fitstate).
