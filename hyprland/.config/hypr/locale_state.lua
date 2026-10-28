-- Language and regional formats chosen from the shell, read separately
-- so you can have an English desktop with French dates, for instance
local state = __require("lib.state")

local locales = {
  fr = "fr_FR.UTF-8",
  us = "en_US.UTF-8",
}

local function read_profile(name, fallback)
  return locales[state.line("locale-" .. name, fallback)] or locales[fallback]
end

return {
  language = read_profile("language", "us"),
  regional = read_profile("regional", "fr"),
}
