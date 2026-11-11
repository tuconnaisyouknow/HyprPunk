-- Catppuccin Mocha in the wallpaper's palette, see-through so kitty's background shows.
-- matugen writes the palette on every new wallpaper, and open Neovims take it at once.
local palette = (vim.env.XDG_STATE_HOME or vim.fn.expand("~/.local/state")) .. "/hyprpunk/nvim-colors.lua"

-- The palette as written, and its colors: Mocha's own until a wallpaper has been set,
-- none while matugen is still writing it, since it empties the file first
local function read_palette()
  local file = io.open(palette)
  if not file then
    return "", {}
  end
  local text = file:read("a")
  file:close()
  local ok, colors = pcall(function()
    return assert(load(text))()
  end)
  return text, ok and type(colors) == "table" and colors or nil
end

return {
  "catppuccin/nvim",
  lazy = false,
  name = "catppuccin",
  priority = 1000,

  config = function()
    local function apply(colors)
      require("catppuccin").setup({
        transparent_background = true,
        color_overrides = { mocha = colors },
        -- The accent across the interface, like the rest of the desktop, where Catppuccin
        -- has blue. Blue stays where it means something, like the info level of the
        -- notifications and the kinds in the completion menu
        custom_highlights = function(colors)
          local accent = { fg = colors.mauve }
          return {
            FloatBorder = accent,
            PmenuBorder = accent,
            PmenuKind = accent,
            PmenuKindSel = accent,
            BlinkCmpMenuBorder = accent,
            Title = accent,
            Directory = accent,
            Folded = accent,
            MoreMsg = accent,
            Question = accent,
            NoiceConfirmBorder = accent,
            SnacksDashboardHeader = accent,
            SnacksDashboardDesc = accent,
            SnacksPickerMatch = accent,
            WhichKeyGroup = accent,
            FidgetTitle = accent,
            RenderMarkdownTableHead = accent,
            MasonHeaderSecondary = accent,
            MasonHighlightBlockBold = accent,
            MasonHighlightBlockSecondary = accent,
          }
        end,
        integrations = {
          -- The status line's normal mode in the accent, and visual mode, which was mauve,
          -- in blue so the two stay apart
          lualine = {
            all = function(colors)
              return {
                normal = {
                  a = { bg = colors.mauve },
                  b = { fg = colors.mauve },
                },
                visual = {
                  a = { bg = colors.blue },
                  b = { fg = colors.blue },
                },
                inactive = {
                  a = { fg = colors.mauve },
                },
              }
            end,
          },
        },
      })
      vim.cmd.colorscheme "catppuccin-mocha"
    end
    local shown, colors = read_palette()
    apply(colors or {})

    -- The folder is watched, since the file may not exist yet. matugen empties the file
    -- then writes it, which fires more than once: a palette is applied once whole and new.
    vim.uv.new_fs_event():start(vim.fs.dirname(palette), {}, vim.schedule_wrap(function(_, name)
      if name ~= vim.fs.basename(palette) then
        return
      end
      local text, new_colors = read_palette()
      if new_colors and text ~= shown then
        shown = text
        apply(new_colors)
      end
    end))
  end
}
