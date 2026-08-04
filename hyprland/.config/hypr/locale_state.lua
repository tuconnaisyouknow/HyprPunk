local locales = {
  fr = "fr_FR.UTF-8",
  us = "en_US.UTF-8",
}

local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")

local function read_profile(name, fallback)
  local state_file = io.open(state_home .. "/hyprpunk/locale-" .. name, "r")
  local profile = state_file and state_file:read("*l") or fallback

  if state_file then
    state_file:close()
  end

  return locales[profile] or locales[fallback]
end

return {
  language = read_profile("language", "us"),
  regional = read_profile("regional", "fr"),
}
