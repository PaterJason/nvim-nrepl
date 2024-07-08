local tcp = require("nrepl.tcp")
local util = require("nrepl.util")

local message = tcp.message

vim.keymap.set("n", "<Plug>(NreplEvalOperator)", function()
  vim.go.operatorfunc = "v:lua.require'nrepl.operator'.eval"
  return "g@"
end, { noremap = true, expr = true })

vim.keymap.set("n", "<Plug>(NreplEvalCursor)", function()
  local pos = vim.api.nvim_win_get_cursor(0)
  pos[1] = pos[1] - 1

  local node = util.get_ts_node("elem", {
    start = pos,
    last = true,
  })
  if node == nil then
    util.open_floating_preview({ "No element found at position" })
    return
  end
  local start = { node:start() }
  local end_ = { node:end_() }

  message.eval_range(start, end_)
end, { noremap = true })
