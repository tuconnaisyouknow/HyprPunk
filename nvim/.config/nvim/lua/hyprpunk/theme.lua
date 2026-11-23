-- The hyprpunk colorscheme's highlight groups, from the wallpaper's palette. The accent
-- and the secondary lead: keywords, titles and what's selected in the accent, fields
-- and names in the secondary. The palette's tones tell the rest of the code apart, and
-- what means something (errors, warnings, git, diffs) takes the fixed colors.
-- colors/hyprpunk.lua draws them; see-through, so kitty's background shows.
local M = {}

-- `fg` laid over `bg` at `alpha`, for tinted backgrounds
local function blend(fg, bg, alpha)
  local function channel(hex, i)
    return tonumber(hex:sub(i, i + 1), 16)
  end
  local out = "#"
  for i = 2, 6, 2 do
    out = out .. string.format("%02x", math.floor(channel(fg, i) * alpha + channel(bg, i) * (1 - alpha) + 0.5))
  end
  return out
end

function M.groups(c)
  local float = c.surface_container_low
  local meanings = {
    Error = c.error,
    Warn = c.yellow,
    Info = c.blue,
    Hint = c.secondary,
    Ok = c.green,
  }

  local g = {
    -- -- THE EDITOR -- --
    Normal = { fg = c.text },
    NormalNC = { fg = c.text },
    NormalFloat = { fg = c.text, bg = float },
    FloatBorder = { fg = c.primary, bg = float },
    FloatTitle = { fg = c.primary, bg = float, bold = true },
    FloatFooter = { fg = c.overlay1, bg = float },
    WinSeparator = { fg = c.surface_container_highest },
    VertSplit = { link = "WinSeparator" },
    ColorColumn = { bg = c.surface_container },
    Conceal = { fg = c.overlay1 },
    Cursor = { fg = c.surface, bg = c.primary },
    lCursor = { link = "Cursor" },
    CursorIM = { link = "Cursor" },
    TermCursor = { link = "Cursor" },
    CursorLine = { bg = blend(c.surface_container, c.surface, 0.6) },
    CursorColumn = { link = "CursorLine" },
    CursorLineNr = { fg = c.primary },
    LineNr = { fg = c.surface_container_highest },
    SignColumn = {},
    FoldColumn = { fg = c.overlay0 },
    Folded = { fg = c.primary, bg = c.surface_container },
    EndOfBuffer = { fg = c.surface },
    NonText = { fg = c.overlay0 },
    Whitespace = { fg = c.surface_container_high },
    SpecialKey = { link = "NonText" },
    Directory = { fg = c.primary },
    Title = { fg = c.primary, bold = true },
    Visual = { bg = c.surface_container_high, bold = true },
    VisualNOS = { link = "Visual" },
    Search = { fg = c.text, bg = blend(c.secondary, c.surface, 0.3) },
    IncSearch = { fg = c.on_primary, bg = c.primary },
    CurSearch = { link = "IncSearch" },
    Substitute = { fg = c.on_primary, bg = c.secondary },
    MatchParen = { fg = c.primary, bg = c.surface_container_high, bold = true },
    QuickFixLine = { bg = c.surface_container, bold = true },
    ModeMsg = { fg = c.text, bold = true },
    MoreMsg = { fg = c.primary },
    Question = { fg = c.primary },
    ErrorMsg = { fg = c.error, bold = true },
    WarningMsg = { fg = c.yellow },
    OkMsg = { fg = c.green },
    StatusLine = { fg = c.text, bg = c.surface_container_low },
    StatusLineNC = { fg = c.overlay1, bg = c.surface_container_low },
    TabLine = { fg = c.overlay1, bg = c.surface_container_lowest },
    TabLineFill = { bg = c.surface_container_lowest },
    TabLineSel = { fg = c.primary, bg = c.surface },
    WinBar = { fg = c.secondary },
    WinBarNC = { fg = c.overlay1 },
    Pmenu = { fg = c.overlay2, bg = float },
    PmenuSel = { bg = c.surface_container, bold = true },
    PmenuSbar = { bg = c.surface_container },
    PmenuThumb = { bg = c.overlay0 },
    PmenuKind = { fg = c.primary },
    PmenuKindSel = { fg = c.primary, bg = c.surface_container, bold = true },
    PmenuExtra = { fg = c.overlay1 },
    PmenuMatch = { fg = c.primary, bold = true },
    WildMenu = { bg = c.surface_container },

    -- -- WHAT MEANS SOMETHING -- --
    -- Spelling, diffs and git in the fixed colors: added, changed, removed
    SpellBad = { sp = c.error, undercurl = true },
    SpellCap = { sp = c.yellow, undercurl = true },
    SpellLocal = { sp = c.blue, undercurl = true },
    SpellRare = { sp = c.green, undercurl = true },
    Added = { fg = c.green },
    Changed = { fg = c.yellow },
    Removed = { fg = c.error },
    DiffAdd = { bg = blend(c.green, c.surface, 0.18) },
    DiffChange = { bg = blend(c.yellow, c.surface, 0.07) },
    DiffDelete = { bg = blend(c.error, c.surface, 0.18) },
    DiffText = { bg = blend(c.yellow, c.surface, 0.25) },
    diffAdded = { link = "Added" },
    diffChanged = { link = "Changed" },
    diffRemoved = { link = "Removed" },
    diffFile = { fg = c.blue },
    diffLine = { fg = c.overlay0 },
    diffIndexLine = { fg = c.overlay1 },
    healthError = { fg = c.error },
    healthWarning = { fg = c.yellow },
    healthSuccess = { fg = c.green },
    DiagnosticDeprecated = { strikethrough = true },
    DiagnosticUnnecessary = { fg = c.overlay1 },

    -- -- THE CODE -- --
    Comment = { fg = c.overlay2, italic = true },
    SpecialComment = { link = "Special" },
    Identifier = { fg = c.text },
    Keyword = { fg = c.primary },
    Statement = { link = "Keyword" },
    Conditional = { fg = c.primary, italic = true },
    Repeat = { link = "Keyword" },
    Exception = { link = "Keyword" },
    Include = { link = "Keyword" },
    StorageClass = { link = "Keyword" },
    String = { fg = c.tone_green },
    Character = { fg = c.tone_teal },
    Constant = { fg = c.tone_orange },
    Number = { link = "Constant" },
    Float = { link = "Constant" },
    Boolean = { link = "Constant" },
    Function = { fg = c.tone_blue },
    Operator = { fg = c.tone_cyan },
    Label = { fg = c.tone_teal },
    Type = { fg = c.tone_yellow },
    Structure = { link = "Type" },
    Typedef = { link = "Type" },
    Special = { fg = c.tone_pink },
    SpecialChar = { link = "Special" },
    PreProc = { fg = c.tone_pink },
    Define = { link = "PreProc" },
    Macro = { link = "PreProc" },
    PreCondit = { link = "PreProc" },
    Tag = { fg = c.tone_blue },
    Delimiter = { fg = c.overlay2 },
    Debug = { fg = c.tone_orange },
    Underlined = { underline = true },
    Bold = { bold = true },
    Italic = { italic = true },
    Error = { fg = c.error },
    Todo = { fg = c.surface, bg = c.yellow, bold = true },

    ["@variable"] = { fg = c.text },
    ["@variable.builtin"] = { fg = c.tone_red },
    ["@variable.parameter"] = { fg = c.tone_red },
    ["@variable.member"] = { fg = c.secondary },
    ["@property"] = { fg = c.secondary },
    ["@module"] = { fg = c.secondary },
    ["@label"] = { link = "Label" },
    ["@constant"] = { link = "Constant" },
    ["@constant.builtin"] = { link = "Constant" },
    ["@constant.macro"] = { link = "Macro" },
    ["@string.escape"] = { fg = c.tone_pink },
    ["@string.regexp"] = { fg = c.tone_pink },
    ["@string.special"] = { fg = c.tone_pink },
    ["@string.special.symbol"] = { link = "Constant" },
    ["@string.special.url"] = { fg = c.primary, underline = true },
    ["@character.special"] = { link = "Special" },
    ["@type.builtin"] = { fg = c.primary },
    ["@attribute"] = { fg = c.tone_orange },
    ["@function.builtin"] = { fg = c.tone_orange },
    ["@function.macro"] = { link = "Macro" },
    ["@constructor"] = { fg = c.tone_teal },
    ["@keyword.conditional"] = { link = "Conditional" },
    ["@keyword.directive"] = { link = "PreProc" },
    ["@punctuation.delimiter"] = { link = "Delimiter" },
    ["@punctuation.bracket"] = { link = "Delimiter" },
    ["@punctuation.special"] = { fg = c.tone_pink },
    ["@tag"] = { link = "Tag" },
    ["@tag.builtin"] = { link = "Tag" },
    ["@tag.attribute"] = { fg = c.tone_yellow, italic = true },
    ["@tag.delimiter"] = { link = "Delimiter" },
    ["@comment.error"] = { fg = c.surface, bg = c.error },
    ["@comment.warning"] = { fg = c.surface, bg = c.yellow },
    ["@comment.todo"] = { fg = c.surface, bg = c.yellow },
    ["@comment.note"] = { fg = c.surface, bg = c.blue },
    ["@diff.plus"] = { link = "Added" },
    ["@diff.minus"] = { link = "Removed" },
    ["@diff.delta"] = { link = "Changed" },
    ["@lsp.mod.deprecated"] = { strikethrough = true },
    ["@lsp.type.comment"] = {},

    -- -- MARKUP -- --
    ["@markup.strong"] = { bold = true },
    ["@markup.italic"] = { italic = true },
    ["@markup.strikethrough"] = { strikethrough = true },
    ["@markup.underline"] = { underline = true },
    ["@markup.heading"] = { fg = c.primary, bold = true },
    ["@markup.quote"] = { fg = c.secondary, italic = true },
    ["@markup.math"] = { fg = c.tone_blue },
    ["@markup.link"] = { fg = c.primary },
    ["@markup.link.label"] = { fg = c.secondary },
    ["@markup.link.url"] = { fg = c.primary, underline = true },
    ["@markup.raw"] = { fg = c.tone_green },
    ["@markup.list"] = { fg = c.tone_teal },
    ["@markup.list.checked"] = { fg = c.tone_green },
    ["@markup.list.unchecked"] = { fg = c.overlay1 },

    -- -- THE LANGUAGE SERVERS -- --
    LspReferenceText = { bg = c.surface_container_high },
    LspReferenceRead = { link = "LspReferenceText" },
    LspReferenceWrite = { link = "LspReferenceText" },
    LspInlayHint = { fg = c.overlay0, bg = blend(c.surface_container, c.surface, 0.5) },
    LspCodeLens = { fg = c.overlay0 },
    LspSignatureActiveParameter = { fg = c.primary, bold = true },
    LspInfoBorder = { link = "FloatBorder" },

    -- -- THE PLUGINS -- --
    -- The completion menu: the kinds in the code's own colors
    BlinkCmpMenu = { link = "Pmenu" },
    BlinkCmpMenuBorder = { fg = c.primary, bg = float },
    BlinkCmpMenuSelection = { link = "PmenuSel" },
    BlinkCmpLabelMatch = { fg = c.primary, bold = true },
    BlinkCmpLabelDeprecated = { fg = c.overlay0, strikethrough = true },
    BlinkCmpGhostText = { fg = c.overlay0 },
    BlinkCmpSource = { fg = c.overlay1 },
    BlinkCmpDoc = { link = "NormalFloat" },
    BlinkCmpDocBorder = { link = "FloatBorder" },
    BlinkCmpSignatureHelpBorder = { link = "FloatBorder" },
    BlinkCmpKind = { fg = c.primary },
    BlinkCmpKindText = { fg = c.overlay2 },
    BlinkCmpKindMethod = { link = "Function" },
    BlinkCmpKindFunction = { link = "Function" },
    BlinkCmpKindConstructor = { link = "@constructor" },
    BlinkCmpKindField = { link = "@variable.member" },
    BlinkCmpKindVariable = { fg = c.text },
    BlinkCmpKindClass = { link = "Type" },
    BlinkCmpKindInterface = { link = "Type" },
    BlinkCmpKindStruct = { link = "Type" },
    BlinkCmpKindEnum = { link = "Type" },
    BlinkCmpKindTypeParameter = { link = "Type" },
    BlinkCmpKindModule = { link = "@module" },
    BlinkCmpKindProperty = { link = "@property" },
    BlinkCmpKindUnit = { link = "Constant" },
    BlinkCmpKindValue = { link = "Constant" },
    BlinkCmpKindEnumMember = { link = "Constant" },
    BlinkCmpKindConstant = { link = "Constant" },
    BlinkCmpKindColor = { link = "Constant" },
    BlinkCmpKindKeyword = { link = "Keyword" },
    BlinkCmpKindOperator = { link = "Operator" },
    BlinkCmpKindSnippet = { fg = c.secondary },
    BlinkCmpKindFile = { link = "Directory" },
    BlinkCmpKindFolder = { link = "Directory" },
    BlinkCmpKindReference = { fg = c.tone_teal },
    BlinkCmpKindEvent = { fg = c.tone_pink },
    BlinkCmpKindCopilot = { fg = c.tone_teal },

    GitSignsAdd = { link = "Added" },
    GitSignsChange = { link = "Changed" },
    GitSignsDelete = { link = "Removed" },
    GitSignsAddInline = { bg = blend(c.green, c.surface, 0.3) },
    GitSignsChangeInline = { bg = blend(c.yellow, c.surface, 0.3) },
    GitSignsDeleteInline = { bg = blend(c.error, c.surface, 0.3) },
    GitSignsAddPreview = { link = "DiffAdd" },
    GitSignsDeletePreview = { link = "DiffDelete" },
    GitSignsCurrentLineBlame = { fg = c.overlay1 },

    -- The icons are kinds of files: the palette's tones
    MiniIconsAzure = { fg = c.tone_cyan },
    MiniIconsBlue = { fg = c.tone_blue },
    MiniIconsCyan = { fg = c.tone_teal },
    MiniIconsGreen = { fg = c.tone_green },
    MiniIconsGrey = { fg = c.overlay2 },
    MiniIconsOrange = { fg = c.tone_orange },
    MiniIconsPurple = { fg = c.tone_pink },
    MiniIconsRed = { fg = c.tone_red },
    MiniIconsYellow = { fg = c.tone_yellow },

    SnacksDashboardHeader = { fg = c.primary },
    SnacksDashboardIcon = { fg = c.primary },
    SnacksDashboardDesc = { fg = c.primary },
    SnacksDashboardKey = { fg = c.secondary },
    SnacksDashboardFooter = { fg = c.secondary },
    SnacksDashboardSpecial = { fg = c.primary },
    SnacksDashboardDir = { fg = c.overlay1 },
    SnacksPickerMatch = { fg = c.primary, bold = true },
    SnacksPickerPrompt = { fg = c.primary },
    SnacksIndent = { fg = c.surface_container_high },
    SnacksIndentScope = { fg = c.overlay1 },

    WhichKey = { fg = c.secondary },
    WhichKeyGroup = { fg = c.primary },
    WhichKeyDesc = { fg = c.text },
    WhichKeySeparator = { fg = c.overlay0 },
    WhichKeyValue = { fg = c.overlay1 },
    WhichKeyNormal = { link = "NormalFloat" },
    WhichKeyBorder = { link = "FloatBorder" },

    FlashLabel = { fg = c.on_primary, bg = c.primary, bold = true },
    FlashMatch = { fg = c.secondary, bg = blend(c.secondary, c.surface, 0.2) },
    FlashCurrent = { fg = c.on_primary, bg = c.secondary },
    FlashBackdrop = { fg = c.overlay0 },

    NoiceCmdlinePopupBorder = { link = "FloatBorder" },
    NoiceCmdlinePopupTitle = { link = "FloatTitle" },
    NoiceCmdlineIcon = { fg = c.primary },
    NoiceConfirmBorder = { link = "FloatBorder" },
    NoicePopupBorder = { link = "FloatBorder" },
    NoiceMini = { bg = float },

    FidgetTitle = { fg = c.primary },
    FidgetTask = { fg = c.overlay1 },

    MasonHeader = { fg = c.on_primary, bg = c.primary, bold = true },
    MasonHeaderSecondary = { fg = c.surface, bg = c.secondary, bold = true },
    MasonHighlight = { fg = c.primary },
    MasonHighlightBlock = { fg = c.on_primary, bg = c.primary },
    MasonHighlightBlockBold = { fg = c.on_primary, bg = c.primary, bold = true },
    MasonHighlightSecondary = { fg = c.secondary },
    MasonHighlightBlockSecondary = { fg = c.surface, bg = c.secondary },
    MasonHighlightBlockBoldSecondary = { fg = c.surface, bg = c.secondary, bold = true },
    MasonMuted = { fg = c.overlay1 },
    MasonMutedBlock = { fg = c.overlay1, bg = c.surface_container },
    MasonMutedBlockBold = { fg = c.overlay1, bg = c.surface_container, bold = true },
    MasonError = { fg = c.error },

    LazyH1 = { fg = c.on_primary, bg = c.primary, bold = true },
    LazyButton = { bg = c.surface_container },
    LazyButtonActive = { fg = c.on_primary, bg = c.primary, bold = true },
    LazySpecial = { fg = c.primary },
    LazyProgressDone = { fg = c.primary },
    LazyProgressTodo = { fg = c.surface_container_high },

    RenderMarkdownCode = { bg = float },
    RenderMarkdownCodeInline = { bg = c.surface_container },
    RenderMarkdownBullet = { link = "@markup.list" },
    RenderMarkdownTableHead = { fg = c.primary },
    RenderMarkdownTableRow = { fg = c.secondary },
  }

  -- Diagnostics in the fixed colors, the hint in the secondary
  for level, color in pairs(meanings) do
    g["Diagnostic" .. level] = { fg = color }
    g["DiagnosticSign" .. level] = { fg = color }
    g["DiagnosticFloating" .. level] = { fg = color }
    g["DiagnosticVirtualText" .. level] = { fg = color, bg = blend(color, c.surface, 0.1) }
    g["DiagnosticUnderline" .. level] = { sp = color, undercurl = true }
  end

  -- Headings lead with the accent and the secondary, then the tones
  local headings = { c.primary, c.secondary, c.tone_red, c.tone_orange, c.tone_yellow, c.tone_green }
  for level, color in ipairs(headings) do
    g["@markup.heading." .. level .. ".markdown"] = { fg = color, bold = true }
    g["RenderMarkdownH" .. level] = { fg = color, bold = true }
    g["RenderMarkdownH" .. level .. "Bg"] = { bg = blend(color, c.surface, 0.15) }
  end

  return g
end

-- The terminal inside Neovim, as kitty colors it
local function terminal(c)
  local ansi = {
    c.surface_container_high, c.error, c.green, c.yellow, c.blue, c.primary, c.tone_cyan, c.subtext1,
    c.surface_container_highest, c.error, c.green, c.yellow, c.blue, c.primary, c.tone_cyan, c.subtext0,
  }
  for i, color in ipairs(ansi) do
    vim.g["terminal_color_" .. (i - 1)] = color
  end
end

function M.load()
  local palette = require("hyprpunk.palette")
  local c = palette.load()
  if vim.g.colors_name then
    vim.cmd("highlight clear")
  end
  vim.o.background = "dark"
  vim.o.termguicolors = true
  vim.g.colors_name = "hyprpunk"
  for group, spec in pairs(M.groups(c)) do
    vim.api.nvim_set_hl(0, group, spec)
  end
  terminal(c)
  palette.watch()
end

return M
