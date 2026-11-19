-- The session's locale: English for the interface, always, and the regional formats
-- chosen from the shell, so you can have French dates on it
local state = __require("lib.state")

local formats = {
  fr = "fr_FR.UTF-8",
  us = "en_US.UTF-8",
}

return {
  language = "en_US.UTF-8",
  regional = formats[state.line("locale-regional", "us")] or formats.us,
}
