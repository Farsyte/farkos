# Boot Files have Moved

The boot file is selected via a GUI element that you
click through the list of files. This is awkward when
there are a lot of them.

So, we move to generic stuff.

Use "boot.ks" for normal missions, which will activate
the package mechanism in "std.ks" and run the "go" code
found in "0:home/{vessel-name}/go.ks" or, if that does
not exist, the closest "go.ks" in a parent directory.

Use "demo.ks" to run one of the demonstration scripts,
which is found in "0:sa/{vessel-name}_demo"

COMING SOON: "test.ks" to run built-in test scripts, as
I start building these up for the various packages where
testing is possible.
