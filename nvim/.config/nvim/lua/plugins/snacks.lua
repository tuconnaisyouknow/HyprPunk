local keyboard = require('config.keyboard')

return {
  'snacks.nvim',
  opts = {
    dashboard = {
      preset = {
        pick = function(cmd, opts)
          return LazyVim.pick(cmd, opts)()
        end,
        header = [[
████████╗██╗   ██╗ ██████╗ ██████╗ ███╗   ██╗███╗   ██╗ █████╗ ██╗███████╗
╚══██╔══╝██║   ██║██╔════╝██╔═══██╗████╗  ██║████╗  ██║██╔══██╗██║██╔════╝
   ██║   ██║   ██║██║     ██║   ██║██╔██╗ ██║██╔██╗ ██║███████║██║███████╗
   ██║   ██║   ██║██║     ██║   ██║██║╚██╗██║██║╚██╗██║██╔══██║██║╚════██║
   ██║   ╚██████╔╝╚██████╗╚██████╔╝██║ ╚████║██║ ╚████║██║  ██║██║███████║
   ╚═╝    ╚═════╝  ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝╚══════╝
]],
        keys = {
          { icon = ' ', key = 'f', desc = 'Find File', action = ":lua Snacks.dashboard.pick('files')" },
          { icon = ' ', key = 'g', desc = 'Live Grep', action = ":lua Snacks.dashboard.pick('live_grep')" },
          { icon = ' ', key = 'c', desc = 'Config', action = ":lua Snacks.dashboard.pick('files', { cwd = vim.fn.stdpath('config') })" },
          { icon = ' ', key = 'x', desc = 'Lazy Extras', action = ':LazyExtras' },
          { icon = '󰒲 ', key = 'l', desc = 'Lazy', action = ':Lazy' },
          { icon = ' ', key = 'm', desc = 'Mason', action = ':Mason' },
          { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' }
        },
      },
    },

    picker = {
      win = {
        input = {
          keys = {
            ["<c-h>"] = false,
            ["<c-j>"] = false,
            ["<c-k>"] = false,
            ["<c-l>"] = false,
            ["<m-" .. keyboard.down .. ">"] = { "list_down", mode = { "i", "n" } },
            ["<m-" .. keyboard.up .. ">"] = { "list_up", mode = { "i", "n" } },
          }
        }
      },
      sources = {
        explorer = {
          hidden = true,
          win = {
            list = {
              keys = {
                ['<c-h>'] = false,
                ['<c-j>'] = false,
                ['<c-k>'] = false,
                ['<c-l>'] = false,
                [keyboard.left] = 'explorer_close',
                [keyboard.down] = 'list_down',
                [keyboard.up] = 'list_up',
                [keyboard.right] = 'confirm',
                [keyboard.extra] = 'explorer_move'
              },
            },
          },
        },
        files = {
          hidden = true
        },
        grep = {
          hidden = true
        }
      },
    },
  },
}
