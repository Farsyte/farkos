{   parameter dbg. // debug package.

    local pr_d is lex(
        "String",       { parameter value.
            return char(34)+value+char(34).
        },
        "Scalar",       { parameter value.
            return round(value, 3).
        },
        "List",         { parameter value.
            local ret is list().
            for e in value
                ret:add(dbg:pr(e)).
            return "["+ret:join(" ")+"]".
        },
        "Vector",       { parameter value.
            local n is value:normalized.
            return dbg:pr(value:mag)+"*"+dbg:pr(list(n:x, n:y, n:z)).
        },
        "Direction",    { parameter value.
            return "[y="+dbg:pr(value:yaw)
                +" p="+dbg:pr(value:pitch)
                +" r="+dbg:pr(value:roll)+"]".
        }).

    dbg:add("pr", { parameter value.
        local t is value:typename.
        if pr_d:haskey(t) return pr_d[t](value).
        return "<"+value:typename+"> "+value:tostring.
    }).

    dbg:add("pv", { parameter name, value.
        print name+": "+dbg:pr(value).
    }).
}