-- The session's locale: English for the interface, always, and the regional formats
-- chosen from the shell, any locale glibc has (locale-profilectl.sh checks it), so you
-- can have German dates on it
local state = __require("lib.state")

return {
  language = "en_US.UTF-8",
  regional = state.line("locale-regional", "en_US.UTF-8"),
}
