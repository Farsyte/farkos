@LAZYGLOBAL off.

runpath("0:/std").
local scan is import("scan").
local dbg is import("dbg").

local delta is 60.
dbg:pv("delta", delta).

local scanner is scan:init(
    { parameter theta. return 1-sin(theta-66.66)^2. },
    { parameter theta. return theta + delta. },
    { parameter theta. set delta to delta/3. return delta < 1/1000. },
    0).

local itercount is 0.
until scanner:step() {
    set itercount to itercount + 1. }

dbg:pv("itercount", itercount).
dbg:pv("scanner:failed", scanner:failed).
dbg:pv("scanner:result", scanner:result).
