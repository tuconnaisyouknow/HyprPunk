-- Colors like #cba6f7 painted in their own color, rgb() too in CSS
return {
  "norcalli/nvim-colorizer.lua",
  config = function()
    require("colorizer").setup({
      "*",
      css = { rgb_fn = true }
    })
  end
}
