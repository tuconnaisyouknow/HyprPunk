-- Tab jumps out of quotes and brackets, Shift+Tab back in
return {
  {
    'abecodes/tabout.nvim',
    lazy = false,
    config = function()
      require('tabout').setup {
        tabkey = '<Tab>',
        backwards_tabkey = '<S-Tab>',
        act_as_tab = true,           -- Nothing to jump out of: a regular Tab
        act_as_shift_tab = false,
        default_tab = '<C-t>',       -- Indent at the start of a line
        default_shift_tab = '<C-d>',
        enable_backwards = true,
        completion = false,          -- Tab is left to the completion menu when it's open
        tabouts = {
          { open = "'", close = "'" },
          { open = '"', close = '"' },
          { open = '`', close = '`' },
          { open = '(', close = ')' },
          { open = '[', close = ']' },
          { open = '{', close = '}' }
        },
        ignore_beginning = true,     -- Right after an opening quote, jump out rather than indent
        exclude = {}
      }
    end,
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "L3MON4D3/LuaSnip",
      "hrsh7th/nvim-cmp"
    },
    opt = true,
    event = 'InsertCharPre', -- Loads with the first character you type
    priority = 1000,
  },
  {
    "L3MON4D3/LuaSnip",
    keys = function()
      -- LuaSnip lets go of Tab, tabout takes it
      return {}
    end,
  },
}
