local state = require("nrepl.state")
local tcp = require("nrepl.tcp")
local util = require("nrepl.util")

local M = {}

---@param prefix string
---@param ns? string
---@return any[]|nil
function M.get_sync(prefix, ns)
  ---@type any[]|nil
  local completions

  tcp.write({
    make_request = function()
      if state.data.server.ops["complete"] then
        return {
          op = "complete",
          prefix = prefix,
          ns = ns,
          ["extra-metadata"] = { "arglists", "doc" },
        }
      else
        return {
          op = "completions",
          prefix = prefix,
          ns = ns,
          options = { ["extra-metadata"] = { "arglists", "doc" } },
        }
      end
    end,
    callback = function(data) completions = data.completions end,
  })

  vim.wait(5000, function() return completions and true or false end, 100)
  return completions
end

local function convert_nrepl_item(item)
  return {
    word = item.candidate,
    info = item.doc,
    menu = item.ns and string.format("%s/%s", item.ns, item.candidate),
    kind = item.type,
  }
end

function M.completefunc(findstart, base)
  if findstart == 1 then
    local pos = vim.api.nvim_win_get_cursor(0)
    pos[1] = pos[1] - 1
    pos[2] = pos[2] - 1
    local node = util.get_ts_node("sym", { start = pos })
    if node then
      local row, column = node:start()
      if row == pos[1] then return column end
    end
  elseif findstart == 0 then
    local completions = M.get_sync(base, util.get_ts_text("ns"))
    return vim.iter(completions):map(convert_nrepl_item):totable()
  end
end

function M.command_customlist(arg_lead, cmd_line, cursor_pos)
  local completions = M.get_sync(arg_lead)
  local candidates = vim
    .iter(completions)
    :map(function(completion) return completion.candidate end)
    :totable()
  return candidates
end

return M
