-- Keyboard layout chosen from the shell. The arrows follow Vim's hjkl,
-- moved to jklm on AZERTY so they stay under the right hand.
local state = __require("lib.state")

local layouts = {
  fr = { name = "fr", xkb = "fr", left = "j", down = "k", up = "l", right = "m" },
  us = { name = "us", xkb = "us", left = "h", down = "j", up = "k", right = "l" },
}

-- US until something else has been picked
return layouts[state.line("keyboard-layout", "us")] or layouts.us
