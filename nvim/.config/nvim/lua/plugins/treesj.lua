-- Split or join a block (arguments, tables, objects) with Space + m, j or s
return {
  'Wansmer/treesj',
  keys = { '<space>m', '<space>j', '<space>s' },
  dependencies = { 'nvim-treesitter/nvim-treesitter' },
  config = function()
    require('treesj').setup({ max_join_length = 9999 })
  end,
}
