return {
  {
    "williamboman/mason.nvim",
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
    "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup()
    end,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    config = function()
      require("mason-tool-installer").setup({
        ensure_installed = {
          -- Bash config
          "bashls",
          "shellcheck",
          "shellharden",
          "shfmt",

          -- Python config
          "pyright",
          "ruff",
          "black",

          -- HTML config
          "html-lsp",
          "htmlhint",
          "prettier",

          -- CSS config
          "cssls",
          "stylelint",

          -- React config
          "ts_ls",
          "tailwindcss",
          "eslint",

          -- Java config
          "jdtls",
          "checkstyle",
          "google-java-format",

          -- Markdown config
          "marksman",
          "markdownlint",

          -- Docker config
          "docker_compose_language_service",
          "dockerls",
          "hadolint",

          -- JSON config
          "jsonls",
          "fixjson",
        },
      })
    end,
  },
}
