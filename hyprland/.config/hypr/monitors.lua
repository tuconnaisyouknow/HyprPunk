-- ################
-- ### MONITORS ###
-- ################

local ACTIVE_MODE = "home"

local monitor_sets = {
  home = {
    -- Home
    { output = "eDP-1",    mode = "1920x1080@60",  position = "1920x0", scale = 1 },
    { output = "HDMI-A-1", mode = "1920x1080@165", position = "0x0",    scale = 1 },
  },
  work = {
    -- Work
    { output = "eDP-1",    mode = "1920x1080@60",  position = "0x0",    scale = 1 },
    { output = "HDMI-A-1", mode = "1920x1080@165", position = "1920x0", scale = 1 },
  },
}

local selected_monitor_set = monitor_sets[ACTIVE_MODE]

if selected_monitor_set == nil then
  error(("Unknown ACTIVE_MODE in monitors.lua: %s"):format(tostring(ACTIVE_MODE)))
end

for _, monitor in ipairs(selected_monitor_set) do
  hl.monitor(monitor)
end
