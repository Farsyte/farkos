function fr { parameter n. for sf in ship:resources if sf:name=n return sf. }
function st { wait until stage:ready. stage. }
local sf is fr("NGNC").
wait until sf:amount<0.05*sf:capacity. st().
