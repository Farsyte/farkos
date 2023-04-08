# Stand-Alone Scripts

Files in this directory are intended to stand alone, to be
runnable directly from a boot script with support from outside
this directory (I must admit the possibility of things being
placed here that use multiple files).

Currently, I've placed some automatic staging code here that
has been shared on Reddit r/kos, which includes some features
suggested by Nuggreat.

I have in my head the idea that I could pick out certain other
specific bits of code that I can make stand-alone, and which
might be useful in isolation to others.

This is my way of admitting that the /pkg and /home areas in this
repo are a mix of interesting ideas and hot-mess-hackery ;)

I'll try to peridocally update this readme with a quick note
on what is going on here.

NOTE: I'm currently writing this after a week or so of being
away from KSP-1 and k-OS, and the /sa/ directory was in a bit
of a flux when I paused work. I'll note what is in the middle
of being worked on. Mostly to remind myself ;)

## autostager

I posted autostager, and got some really good feedback, with
the eventual result that I will be making some changes. These
are not quite ready but as a consequence, autostager itself
will not be using the "WHEN..THEN" constuct.

The sa/autostager.ks file remains, pointing to the WHEN-based
version of the code, for those that want to use it and are
willing to pay the "WHEN" tax.

### autostager_when

This is the version of autostager that makes use of a WHEN-based
scheduling mechanism. It works, and can be used for modest
sized projects, with the following impacts.

Every physical tick, the "time_svc" mecahnism will be waking
up at an elevated interrupt level. Most of the time, this will
just be for a "compare current time to a variable" check, but
every second or so, it also checks to see if the stage number
has changed or the maximum thrust is zero. Less common, it
will fetch the list of engines to see if we have any. Rarely,
it will decide we need to stage.

(This is improved over the originally posted version, the use
of availablethrust to detect potential flameout means that
we only enumerate engines if we have no thrust.)

### autostager_when_demo

A bootable script that loads up autostager_when, starts it going
and demonstrates the tasking facility in action. The demonstration
is best if the time thresholds are adjusted to fit the rocket used
during the test; I like to have it stage before the pause, then be
ready to stage again before the resume, and have another stage be
ready between the cancel and the restart.


## nonvolatile

This package allows storing values to named nonvolatile storage,
which can be recalled after a processor reboots. For example, if
your mission plan is a list of things to do, and you are doing the
fifth one, it is nice to start with the fifth one if you reboot.

### nonvolatile_demo

This script starts by setting up a count, and rebooting (adding one
to the count each time) to show that data can be recovered after
a boot. It then demonstrates heirarchical data - basically, allowing
the caller to clear out a tree of items (for example, discarding a
target orbit with seven data items all in one call).

## scheduler

allow a caller to ask for us to call a specified function at or
after a specfied universal time, to reschedule the call as requested
by the return value of the call, and of course a loop to actually
process the list of scheduled calls.

This version of the scheduler does not use "WHEN..THEN" constructs.


### scheduler_demo

Builds some tasks with different delays, and starts them going.

## sequencer

My missions have a Main Sequence: a list of things that the mission
needs to do (such as Launch, Ascend, Coast, Circularize, Planeshift,
Transfer, Match, Approach, Deorbit, Aerobrake, Parachutes, and Park).

In my code, each of these is a single function, which is called over
and over until it says it is done.

Sequencer carries the list of these functions, and handles the process
of calling the right one, repeatedly, with appropriate delays, until it
is time to go on to the next one.

This basically has two parts: building the list, and executing it.

### sequencer demo does not exist yet.

I was just starting to write this when other things happened,
so this is COMING SOON[tm].
