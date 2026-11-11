-- Catppuccin Mocha in the wallpaper's palette, see-through so kitty's background shows.
-- matugen writes the palette on every new wallpaper, and open Neovims take it at once.
local palette = (vim.env.XDG_STATE_HOME or vim.fn.expand("~/.local/state")) .. "/hyprpunk/nvim-colors.lua"

-- Mocha's own colors until a wallpaper has been set
local function palette_colors()
  local ok, colors = pcall(dofile, palette)
  return ok and colors or {}
end

return {
  "catppuccin/nvim",
  lazy = false,
  name = "catppuccin",
  priority = 1000,

  config = function()
    local function apply()
      require("catppuccin").setup({
        transparent_background = true,
        color_overrides = { mocha = palette_colors() },
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
    apply()

    -- matugen may swap the file for a new one, so its folder is what's watched
    vim.uv.new_fs_event():start(vim.fs.dirname(palette), {}, vim.schedule_wrap(function(_, name)
      if name == vim.fs.basename(palette) then
        apply()
      end
    end))
  end
}
