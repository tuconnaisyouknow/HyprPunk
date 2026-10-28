-- Language servers, linters and formatters, installed on their own by Mason
return {
  {
    "mason-org/mason.nvim",
    config = function()
      require("mason").setup({
        ui = {
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗",
          },
        },
      })
    end,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup()
    end,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    config = function()
      require("mason-tool-installer").setup({
        ensure_installed = {
          -- Bash
          "bashls",
          "shellcheck",
          "shellharden",
          "shfmt",

          -- Python
          "pyright",
          "ruff",
          "black",

          -- HTML
          "html-lsp",
          "htmlhint",
          "prettier",

          -- CSS
          "cssls",
          "stylelint",

          -- React
          "ts_ls",
          "tailwindcss",
          "eslint",

          -- Java
          "jdtls",
          "checkstyle",
          "google-java-format",

          -- Markdown
          "marksman",
          "markdownlint",

          -- Docker
          "docker_compose_language_service",
          "dockerls",
          "hadolint",

          -- JSON
          "jsonls",
          "fixjson",

          -- Hyprland
          "hyprls",
        },
      })
    end,
  },
}
