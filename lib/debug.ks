
// term(w,h): open the console terminal.
// optional parameters can be used to set the size.
function term {
    parameter w is terminal:width.
    parameter h is terminal:height.
    set terminal:height to h.
    set terminal:width to w.
    if career():candoactions
        core:doAction("open terminal", true).
}

term().

// debug print conversions for various types.
local pr_d is lex().
set pr_d["String"] to { parameter value.
    return char(34)+value+char(34). }.
set pr_d["Scalar"] to { parameter value.
    return round(value, 3). }.
set pr_d["List"] to { parameter value.
    local ret is list().
    for e in value ret:add(pr(e)).
    return "["+ret:join(" ")+"]". }.
set pr_d["Vector"] to { parameter value.
    local n is value:normalized.
    return pr(value:mag)+"*"+pr(list(n:x, n:y, n:z)). }.
set pr_d["Direction"] to { parameter value.
    return "[y="+pr(value:yaw)+" p="+pr(value:pitch)+" r="+pr(value:roll)+"]". }.

//
// pr(value): return printable string for value
// falls back to "<type> tostring" for unrecognized types.
function pr { parameter value.
    local t is value:typename.
    if pr_d:haskey(t) return pr_d[t](value).
    return "<"+value:typename+"> "+value:tostring.
}
function pv { parameter name, value.
    print name+": "+pr(value).
}