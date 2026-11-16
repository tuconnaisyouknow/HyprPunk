-- Reads the shell's glass style saved by glassctl.sh. The liquid glass is more
-- see-through, so the layers' blur has to reach fainter pixels for it to show.
local state = __require("lib.state")

local liquid = state.line("glass-style", "classic") == "liquid"

return {
  liquid = liquid,
  -- How opaque a pixel must be to get blurred behind: just under the faintest fill of
  -- the style (the liquid glass's bottom is at 0.36), so the blur stops where the
  -- glass already covers what's behind rather than out on its soft edge
  ignore_alpha = liquid and 0.33 or 0.5,
}
