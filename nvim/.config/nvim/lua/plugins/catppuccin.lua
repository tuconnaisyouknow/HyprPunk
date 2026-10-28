-- Catppuccin Mocha, see-through so kitty's background shows
return {
  "catppuccin/nvim",
  lazy = false,
  name = "catppuccin",
  priority = 1000,

  config = function()
    require("catppuccin").setup({
      transparent_background = true,
      -- Mauve as the accent like the rest of the desktop, on the interface only, so the
      -- code keeps Catppuccin's usual colors. Blue stays where it means something, like
      -- the info level of the notifications and the kinds in the completion menu
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
        -- The status line's normal mode in mauve, and visual mode, which was mauve,
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
}
