// term: open a terminal for feedback to the pilot
export({ parameter h is 16, w is 64.
  clearscreen.
  set terminal:width to w.
  set terminal:height to h.
  if career():candoactions
    core:doAction("open terminal", true).
  // clearscreen.
}).
