@LAZYGLOBAL off.
{   parameter fmt is lex(). // Maneuver Node Execution

    fmt:add("s", { // format string value in fixed width field.
        parameter val. // required parameter is value to format
        parameter w is 0. // optional parameter w is width of field

        local width_neg is false.

        if w < 0 { set width_neg to true. set w to -w. }

        // just in case the thing passed is not actually a string.
        set val to val:tostring.

        local pad_width is w-val:length.
        local pad_str is "".
        until pad_str:length >= pad_width set pad_str to pad_str + " ".

        if width_neg            set val to val+pad_str.
        else                    set val to pad_str+val.

        return val. }).

    fmt:add("d", { // format integer value in fixed width field.
        parameter val. // required parameter is value to format
        parameter w is 0. // optional parameter w is width of field
        parameter f is "". // optional parameter f is formatting flags

        local flag_plus is false.
        local flag_zero is false.
        local width_neg is false.
        local sign_str is "".

        if w < 0 { set width_neg to true. set w to -w. }

        for ch in f {
            if ch = "+" set flag_plus to true.
            if ch = "0" set flag_zero to true. }

        if flag_plus set sign_str to "+".

        set val to round(val). if val < 0 {
            set val to -val. set sign_str to "-". }
        set val to val:tostring.

        local pad_width is w-sign_str:length-val:length.
        local pad_str is "".
        local pad_char is choose "0" if flag_zero else " ".
        until pad_str:length >= pad_width set pad_str to pad_str + pad_char.

        if width_neg            set val to sign_str+val+pad_str.
        else if flag_zero       set val to sign_str+pad_str+val.
        else                    set val to pad_str+sign_str+val.

        return val. }).

    fmt:add("f", { // format integer value in fixed width field.
        parameter val. // required parameter is value to format
        parameter w is 0. // optional parameter w is width of field
        parameter d is 0. // optional parameter d is number of decimal places
        parameter f is "". // optional parameter f is formatting flags

        if d <= 0 return fmt:d(val, w, f).

        local flag_plus is false.
        local flag_zero is false.
        local width_neg is false.
        local sign_str is "".

        if w < 0 { set width_neg to true. set w to -w. }

        for ch in f {
            if ch = "+" set flag_plus to true.
            if ch = "0" set flag_zero to true. }

        if flag_plus set sign_str to "+".

        set val to round(val,d). if val < 0 {
            set val to -val. set sign_str to "-". }
        set val to val:tostring.
        set val to val:split(".").
        if val:length < 2 val:add("0").

        until val[1]:length >= d set val[1] to val[1] + "0".
        set val to val:join(".").

        local pad_width is w-sign_str:length-val:length.
        local pad_str is "".
        local pad_char is choose "0" if flag_zero else " ".
        until pad_str:length >= pad_width set pad_str to pad_str + pad_char.

        if width_neg            set val to sign_str+val+pad_str.
        else if flag_zero       set val to sign_str+pad_str+val.
        else                    set val to pad_str+sign_str+val.

        return val. }).
}