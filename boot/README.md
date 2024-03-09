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
which is found in "0:sa/{vessel-name}_demo.ks"

Use "sa.ks" to run one of the standalonescripts,
which is found in "0:sa/{vessel-name}.ks"

COMING SOON: "test.ks" to run built-in test scripts, as
I start building these up for the various packages where
testing is possible.

## are we connected to the archive?

A bit of knowledge that dropped out of this repo.

To copy a file IF AND ONLY IF we have a connection
to the archive,

    wait 3.
    if homeconnection:isconnected
      copypath("0:/dir/file.ks","file.ks").

Note that "isconnected" may be False for a few seconds
after loading, which is why the 'wait 3' is there.

This is useful for exploration craft that will be going
where there is no network connection.

These craft would need a modified "import" that can cache modules on
the craft and run them from the craft when not connected.

