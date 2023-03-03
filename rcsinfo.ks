list rcs in rcs_list.
local rcs_thrust is 0.
for it in rcs_list {
    set rcs_thrust to rcs_thrust + it:availablethrust. }
print "rcs_thrust: "+rcs_thrust.