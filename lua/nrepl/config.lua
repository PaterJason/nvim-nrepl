---@alias Nrepl.RequestParam.Bool 1|vim.NIL
---@alias Nrepl.RequestParam.Integer integer|vim.NIL
---@alias Nrepl.RequestParam.String string|vim.NIL
---@alias Nrepl.RequestParam.StringList string[]|vim.NIL

---@class Nrepl.Config
local M = {
  ---@type vim.lsp.util.open_floating_preview.Opts
  floating_preview = {
    border = "single",
    title = "nREPL",
    focusable = true,
    focus_id = "nvim.nrepl",
    wrap = false,
  },
  middleware_params = {
    ---@type Nrepl.RequestParam.String
    -- ["nrepl.middleware.print/print"] = "nrepl.util.print/pr",
    ["nrepl.middleware.print/print"] = "cider.nrepl.pprint/fipp-pprint",
    ["nrepl.middleware.print/options"] = {
      ---@type Nrepl.RequestParam.Bool
      ["print-dup"] = 1,
      ---@type Nrepl.RequestParam.Integer
      ["print-length"] = 50,
      ---@type Nrepl.RequestParam.Integer
      ["print-level"] = 10,
      ---@type Nrepl.RequestParam.Bool
      ["print-meta"] = nil,
      ---@type Nrepl.RequestParam.Bool
      ["print-namespace-maps"] = nil,
      ---@type Nrepl.RequestParam.Bool
      ["print-readably"] = nil,
    },
    ---@type Nrepl.RequestParam.Bool
    ["nrepl.middleware.print/stream?"] = 1,
    ---@type Nrepl.RequestParam.Integer
    ["nrepl.middleware.print/buffer-size"] = nil,
    ---@type Nrepl.RequestParam.Integer
    ["nrepl.middleware.print/quota"] = nil,
    ---@type Nrepl.RequestParam.StringList
    ["nrepl.middleware.print/keys"] = nil,

    ---@type Nrepl.RequestParam.String
    ["nrepl.middleware.caught/caught"] = nil,
    ---@type Nrepl.RequestParam.Bool
    ["nrepl.middleware.caught/print?"] = nil,
  },
  -- Debug printing
  ---@type boolean
  debug = false,
}

return M
