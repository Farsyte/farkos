@lazyglobal on.
clearvecdraws().

// [0 0 1] = facing:inverse * facing:vector
//
// [1 0 0] = facing:inverse * facing:starvector
// [0 1 0] = facing:inverse * facing:upvector
// [0 0 1] = facing:inverse * facing:forevector
//
// so if i have a vector VEC in ship-raw,
// then facing:inverse*VEC gives a vector
// whose components are the
//     [starvector, upvector, forevector]
// components in the facing coordinate system.

// hmmm.
//     set SHIP:CONTROL:TRANSLATION to facing:inverse*VEC
// sets RCS to thrust in the SHIP-RAW VEC direction.
//
// remember to SHIP:CONTROL:NEUTRALIZE when done.
{
    local pr_d is lex(
        "Boolean",      { parameter value.
            return choose "TRUE" if value else "FALSE". },
        "String",       { parameter value.
            return char(34)+value+char(34). },
        "Scalar",       { parameter value.
            return round(value, 3). },
        "List",         { parameter value.
            local ret is list().
            for e in value
                ret:add(pr(e)).
            return "["+ret:join(" ")+"]". },
        "Lexicon",       { parameter value.
            local ret is list().
            local nl is "". // char(10).
            local nlin is " ". // nl+"  ".
            for k in value:keys
                ret:add(pr(k)+" => "+pr(value[k])).
            return "LEX{"+nlin+ret:join(","+nlin)+nl+"}". },
        "Vector",       { parameter value.
            local n is value:normalized.
            return pr(value:mag)+"*"+pr(list(n:x, n:y, n:z)). },
        "Direction",    { parameter value.
            return "[y="+pr(value:yaw)
                +" p="+pr(value:pitch)
                +" r="+pr(value:roll)+"]". }).

    global pr is { parameter value.            // useful printable representation
        local t is value:typename.
        if pr_d:haskey(t) return pr_d[t](value).
        return "<"+value:typename+"> "+value:tostring. }.

    global pv is { parameter name, value.      // print name and representation of value
        print name+": "+pr(value). }.
}

// facing:x is

set drawn to list().
set l to 1.
set f to facing.

pv("f", f).                                                     // facing

pv("f:forevector is ", f:forevector).                           // ...
pv("f:starvector is ", f:starvector).                           // ...
pv("f:upvector is ", f:upvector).                               // ...
pv("f:vector is ", f:vector).                                   // ...

pv("[Z] f:inverse*f:vector is ", f:inverse*f:vector).           // 0 0 1

pv("[X] f:inverse*f:starvector is ", f:inverse*f:starvector).   // 1 0 0
pv("[Y] f:inverse*f:upvector is ", f:inverse*f:upvector).       // 0 1 0
pv("[Z] f:inverse*f:forevector is ", f:inverse*f:forevector).   // 0 0 1

set fx to f*V(L,0,0). pv("fx = ", fx).                          // ...
set fy to f*V(0,L,0). pv("fy = ", fy).                          // ...
set fz to f*V(0,0,L). pv("fz = ", fz).                          // ...

set rx to f:inverse*fx. pv("rx = ", rx).                        // 1 0 0
set ry to f:inverse*fy. pv("ry = ", ry).                        // 0 1 0
set rz to f:inverse*fz. pv("rz = ", rz).                        // 0 0 1

// drawn:add(vecdraw(V(0,0,0),facing:vector*L,RGB(1,0,0),"Facing",1,TRUE,0.2,TRUE,TRUE)).
// drawn:add(vecdraw(V(0,0,0),fx,RGB(1,0,0),"Facing*X",1,TRUE,0.2,TRUE,TRUE)).
// drawn:add(vecdraw(V(0,0,0),fy,RGB(1,0,0),"Facing*Y",1,TRUE,0.2,TRUE,TRUE)).
// drawn:add(vecdraw(V(0,0,0),fz,RGB(1,0,0),"Facing*Z",1,TRUE,0.2,TRUE,TRUE)).

// wait until false.