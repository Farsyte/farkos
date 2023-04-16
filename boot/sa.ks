core:doAction("open terminal", true).
local name is ship:name.
print "Hello, " + name.
local na is name:split("/").
set na[0] to "0:sa".
local sa is na:join("/")+"_demo".
print "Running " + sa.
runpath(sa).
